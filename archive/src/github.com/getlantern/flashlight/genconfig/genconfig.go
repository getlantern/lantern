package main

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"text/template"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
	"github.com/getlantern/yaml"

	"github.com/getlantern/flashlight/client"
)

const (
	numberOfWorkers = 50
	ftVersionFile   = `https://raw.githubusercontent.com/firetweet/downloads/master/version.txt`
	defaultDeviceID = "555"
)

var (
	help                = flag.Bool("help", false, "Get usage help")
	masqueradesInFile   = flag.String("masquerades", "", "Path to file containing list of pasquerades to use, with one space-separated 'ip domain' pair per line (e.g. masquerades.txt)")
	masqueradesOutFile  = flag.String("masquerades-out", "", "Path, if any, to write the go-formatted masquerades configuration.")
	blacklistFile       = flag.String("blacklist", "", "Path to file containing list of blacklisted domains, which will be excluded from the configuration even if present in the masquerades file (e.g. blacklist.txt)")
	proxiedSitesDir     = flag.String("proxiedsites", "proxiedsites", "Path to directory containing proxied site lists, which will be combined and proxied by Lantern")
	proxiedSitesOutFile = flag.String("proxiedsites-out", "", "Path, if any, to write the go-formatted proxied sites configuration.")
	minFreq             = flag.Float64("minfreq", 3.0, "Minimum frequency (percentage) for including CA cert in list of trusted certs, defaults to 3.0%")

	fallbacksFile    = flag.String("fallbacks", "fallbacks.yaml", "File containing yaml dict of fallback information")
	fallbacksOutFile = flag.String("fallbacks-out", "", "Path, if any, to write the go-formatted fallback configuration.")
)

var (
	log = golog.LoggerFor("genconfig")

	masquerades []string

	blacklist    = make(filter)
	proxiedSites = make(filter)
	fallbacks    map[string]*client.ChainedServerInfo
	ftVersion    string

	inputCh       = make(chan string)
	masqueradesCh = make(chan *masquerade)
	wg            sync.WaitGroup
)

type filter map[string]bool

type masquerade struct {
	Domain    string
	IpAddress string
	RootCA    *castat
}

type castat struct {
	CommonName string
	Cert       string
	freq       float64
}

func main() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	numcores := runtime.NumCPU()
	log.Debugf("Using all %d cores on machine", numcores)
	runtime.GOMAXPROCS(numcores)

	loadMasquerades()
	loadProxiedSitesList()
	loadBlacklist()
	loadFallbacks()
	loadFtVersion()

	yamlTmpl := loadTemplate("cloud.yaml.tmpl")

	go feedMasquerades()
	cas, masqs := coalesceMasquerades()
	model := buildModel(cas, masqs, false)
	generateTemplate(model, yamlTmpl, "cloud.yaml")
	model = buildModel(cas, masqs, true)
	generateTemplate(model, yamlTmpl, "lantern.yaml")
	var err error
	if *masqueradesOutFile != "" {
		masqueradesTmpl := loadTemplate("masquerades.go.tmpl")
		generateTemplate(model, masqueradesTmpl, *masqueradesOutFile)
		_, err = run("gofmt", "-w", *masqueradesOutFile)
		if err != nil {
			log.Fatalf("Unable to format %s: %s", *masqueradesOutFile, err)
		}
	}
	if *proxiedSitesOutFile != "" {
		proxiedSitesTmpl := loadTemplate("proxiedsites.go.tmpl")
		generateTemplate(model, proxiedSitesTmpl, *proxiedSitesOutFile)
		_, err = run("gofmt", "-w", *proxiedSitesOutFile)
		if err != nil {
			log.Fatalf("Unable to format %s: %s", *proxiedSitesOutFile, err)
		}
	}
	if *fallbacksOutFile != "" {
		fallbacksTmpl := loadTemplate("fallbacks.go.tmpl")
		generateTemplate(model, fallbacksTmpl, *fallbacksOutFile)
		_, err = run("gofmt", "-w", *fallbacksOutFile)
		if err != nil {
			log.Fatalf("Unable to format %s: %s", *fallbacksOutFile, err)
		}
	}
}

func loadMasquerades() {
	if *masqueradesInFile == "" {
		log.Error("Please specify a masquerades file")
		flag.Usage()
		os.Exit(2)
	}
	bytes, err := ioutil.ReadFile(*masqueradesInFile)
	if err != nil {
		log.Fatalf("Unable to read masquerades file at %s: %s", *masqueradesInFile, err)
	}
	masquerades = strings.Split(string(bytes), "\n")
}

// Scans the proxied site directory and stores the sites in the files found
func loadProxiedSites(path string, info os.FileInfo, err error) error {
	if info.IsDir() {
		// skip root directory
		return nil
	}
	proxiedSiteBytes, err := ioutil.ReadFile(path)
	if err != nil {
		log.Fatalf("Unable to read blacklist file at %s: %s", path, err)
	}
	for _, domain := range strings.Split(string(proxiedSiteBytes), "\n") {
		// skip empty lines, comments, and *.ir sites
		// since we're focusing on Iran with this first release, we aren't adding *.ir sites
		// to the global proxied sites
		// to avoid proxying sites that are already unblocked there.
		// This is a general problem when you aren't maintaining country-specific whitelists
		// which will be addressed in the next phase
		if domain != "" && !strings.HasPrefix(domain, "#") && !strings.HasSuffix(domain, ".ir") {
			proxiedSites[domain] = true
		}
	}
	return err
}

func loadProxiedSitesList() {
	if *proxiedSitesDir == "" {
		log.Error("Please specify a proxied site directory")
		flag.Usage()
		os.Exit(3)
	}

	err := filepath.Walk(*proxiedSitesDir, loadProxiedSites)
	if err != nil {
		log.Errorf("Could not open proxied site directory: %s", err)
	}
}

func loadFtVersion() {
	res, err := http.Get(ftVersionFile)
	if err != nil {
		log.Fatalf("Error fetching FireTweet version file: %s", err)
	}

	defer func() {
		if err := res.Body.Close(); err != nil {
			log.Debugf("Error closing response body: %v", err)
		}
	}()
	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		log.Fatalf("Could not read FT version file: %s", err)
	}
	ftVersion = strings.TrimSpace(string(body))
}

func loadBlacklist() {
	if *blacklistFile == "" {
		log.Error("Please specify a blacklist file")
		flag.Usage()
		os.Exit(3)
	}
	blacklistBytes, err := ioutil.ReadFile(*blacklistFile)
	if err != nil {
		log.Fatalf("Unable to read blacklist file at %s: %s", *blacklistFile, err)
	}
	for _, domain := range strings.Split(string(blacklistBytes), "\n") {
		blacklist[domain] = true
	}
}

func loadFallbacks() {
	if *fallbacksFile == "" {
		log.Error("Please specify a fallbacks file")
		flag.Usage()
		os.Exit(2)
	}
	fallbacksBytes, err := ioutil.ReadFile(*fallbacksFile)
	if err != nil {
		log.Fatalf("Unable to read fallbacks file at %s: %s", *fallbacksFile, err)
	}
	err = yaml.Unmarshal(fallbacksBytes, &fallbacks)
	if err != nil {
		log.Fatalf("Unable to unmarshal yaml from %v: %v", *fallbacksFile, err)
	}
}

func loadTemplate(name string) string {
	bytes, err := ioutil.ReadFile(name)
	if err != nil {
		log.Fatalf("Unable to load template %s: %s", name, err)
	}
	return string(bytes)
}

func feedMasquerades() {
	wg.Add(numberOfWorkers)
	for i := 0; i < numberOfWorkers; i++ {
		go grabCerts()
	}

	for _, masq := range masquerades {
		if masq != "" {
			inputCh <- masq
		}
	}
	close(inputCh)
	wg.Wait()
	close(masqueradesCh)
}

// grabCerts grabs certificates for the masquerades received on masqueradesCh and sends
// *masquerades to masqueradesCh.
func grabCerts() {
	defer wg.Done()

	for masq := range inputCh {
		parts := strings.Split(masq, " ")
		if len(parts) != 2 {
			log.Error("Bad line! '" + masq + "'")
			continue
		}
		ip := parts[0]
		domain := parts[1]
		_, blacklisted := blacklist[domain]
		if blacklisted {
			log.Tracef("Domain %s is blacklisted, skipping", domain)
			continue
		}
		log.Tracef("Grabbing certs for IP %s, domain %s", ip, domain)
		cwt, err := tlsdialer.DialForTimings(net.DialTimeout, 10*time.Second, "tcp", ip+":443", false, &tls.Config{ServerName: domain})
		if err != nil {
			log.Errorf("Unable to dial IP %s, domain %s: %s", ip, domain, err)
			continue
		}
		if err := cwt.Conn.Close(); err != nil {
			log.Debugf("Error closing connection: %v", err)
		}
		chain := cwt.VerifiedChains[0]
		rootCA := chain[len(chain)-1]
		rootCert, err := keyman.LoadCertificateFromX509(rootCA)
		if err != nil {
			log.Errorf("Unable to load keyman certificate: %s", err)
			continue
		}
		ca := &castat{
			CommonName: rootCA.Subject.CommonName,
			Cert:       strings.Replace(string(rootCert.PEMEncoded()), "\n", "\\n", -1),
		}
		masqueradesCh <- &masquerade{
			Domain:    domain,
			IpAddress: ip,
			RootCA:    ca,
		}
	}
}

func coalesceMasquerades() (map[string]*castat, []*masquerade) {
	count := 0
	allCAs := make(map[string]*castat)
	allMasquerades := make([]*masquerade, 0)
	for masquerade := range masqueradesCh {
		count = count + 1
		ca := allCAs[masquerade.RootCA.Cert]
		if ca == nil {
			ca = masquerade.RootCA
		}
		ca.freq = ca.freq + 1
		allCAs[ca.Cert] = ca
		allMasquerades = append(allMasquerades, masquerade)
	}

	// Trust only those cas whose relative frequency exceeds *minFreq
	trustedCAs := make(map[string]*castat)
	for _, ca := range allCAs {
		// Make frequency relative
		ca.freq = float64(ca.freq*100) / float64(count)
		if ca.freq > *minFreq {
			trustedCAs[ca.Cert] = ca
		}
	}

	// Pick only the masquerades associated with the trusted certs
	trustedMasquerades := make([]*masquerade, 0)
	for _, masquerade := range allMasquerades {
		_, caFound := trustedCAs[masquerade.RootCA.Cert]
		if caFound {
			trustedMasquerades = append(trustedMasquerades, masquerade)
		}
	}

	return trustedCAs, trustedMasquerades
}

func buildModel(cas map[string]*castat, masquerades []*masquerade, useFallbacks bool) map[string]interface{} {
	casList := make([]*castat, 0, len(cas))
	for _, ca := range cas {
		casList = append(casList, ca)
	}
	sort.Sort(ByFreq(casList))
	sort.Sort(ByDomain(masquerades))
	ps := make([]string, 0, len(proxiedSites))
	for site, _ := range proxiedSites {
		ps = append(ps, site)
	}
	sort.Strings(ps)
	fbs := make([]map[string]interface{}, 0, len(fallbacks))
	if useFallbacks {
		for _, f := range fallbacks {
			fb := make(map[string]interface{})
			fb["ip"] = f.Addr
			fb["auth_token"] = f.AuthToken

			cert := f.Cert
			// Replace newlines in cert with newline literals
			fb["cert"] = strings.Replace(cert, "\n", "\\n", -1)

			info := f
			dialer, err := client.ChainedDialer(info, defaultDeviceID)
			if err != nil {
				log.Debugf("Skipping fallback %v because of error building dialer: %v", f.Addr, err)
				continue
			}
			conn, err := dialer.DialFN("tcp", "http://www.google.com")
			if err != nil {
				log.Debugf("Skipping fallback %v because dialing Google failed: %v", f.Addr, err)
				continue
			}
			if err := conn.Close(); err != nil {
				log.Debugf("Error closing connection: %v", err)
			}

			// Use this fallback
			fbs = append(fbs, fb)
		}
	}
	return map[string]interface{}{
		"cas":          casList,
		"masquerades":  masquerades,
		"proxiedsites": ps,
		"fallbacks":    fbs,
		"ftVersion":    ftVersion,
	}
}

func generateTemplate(model map[string]interface{}, tmplString string, filename string) {
	tmpl, err := template.New(filename).Funcs(funcMap).Parse(tmplString)
	if err != nil {
		log.Errorf("Unable to parse template: %s", err)
		return
	}
	out, err := os.Create(filename)
	if err != nil {
		log.Errorf("Unable to create %s: %s", filename, err)
		return
	}
	defer func() {
		if err := out.Close(); err != nil {
			log.Debugf("Error closing file: %v", err)
		}
	}()
	err = tmpl.Execute(out, model)
	if err != nil {
		log.Errorf("Unable to generate %s: %s", filename, err)
	}
}

func run(prg string, args ...string) (string, error) {
	cmd := exec.Command(prg, args...)
	log.Debugf("Running %s %s", prg, strings.Join(args, " "))
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s says %s", prg, string(out))
	}
	return string(out), nil
}

func base64Encode(sites []string) string {
	raw, err := json.Marshal(sites)
	if err != nil {
		panic(fmt.Errorf("Unable to marshal proxied sites: %s", err))
	}
	b64 := base64.StdEncoding.EncodeToString(raw)
	return b64
}

// the functions to be called from template
var funcMap = template.FuncMap{
	"encode": base64Encode,
}

type ByDomain []*masquerade

func (a ByDomain) Len() int           { return len(a) }
func (a ByDomain) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByDomain) Less(i, j int) bool { return a[i].Domain < a[j].Domain }

type ByFreq []*castat

func (a ByFreq) Len() int           { return len(a) }
func (a ByFreq) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByFreq) Less(i, j int) bool { return a[i].freq > a[j].freq }
