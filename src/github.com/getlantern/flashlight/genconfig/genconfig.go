package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
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

	"github.com/getlantern/flashlight/client"
)

const (
	numberOfWorkers = 50
)

var (
	help            = flag.Bool("help", false, "Get usage help")
	domainsFile     = flag.String("domains", "", "Path to file containing list of domains to use, with one domain per line (e.g. domains.txt)")
	blacklistFile   = flag.String("blacklist", "", "Path to file containing list of blacklisted domains, which will be excluded from the configuration even if present in the domains file (e.g. blacklist.txt)")
	proxiedSitesDir = flag.String("proxiedsites", "proxiedsites", "Path to directory containing proxied site lists, which will be combined and proxied by Lantern")
	minFreq         = flag.Float64("minfreq", 3.0, "Minimum frequency (percentage) for including CA cert in list of trusted certs, defaults to 3.0%")

	// Note - you can get the content for the fallbacksFile from https://lanternctrl1-2.appspot.com/listfallbacks
	fallbacksFile = flag.String("fallbacks", "fallbacks.json", "File containing json array of fallback information")
)

var (
	log = golog.LoggerFor("genconfig")

	domains []string

	blacklist    = make(filter)
	proxiedSites = make(filter)
	fallbacks    []map[string]interface{}

	domainsCh     = make(chan string)
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

	loadDomains()
	loadProxiedSitesList()
	loadBlacklist()
	loadFallbacks()

	masqueradesTmpl := loadTemplate("masquerades.go.tmpl")
	proxiedSitesTmpl := loadTemplate("proxiedsites.go.tmpl")
	fallbacksTmpl := loadTemplate("fallbacks.go.tmpl")
	yamlTmpl := loadTemplate("cloud.yaml.tmpl")

	go feedDomains()
	cas, masquerades := coalesceMasquerades()
	model := buildModel(cas, masquerades)
	generateTemplate(model, yamlTmpl, "cloud.yaml")
	generateTemplate(model, masqueradesTmpl, "../config/masquerades.go")
	_, err := run("gofmt", "-w", "../config/masquerades.go")
	if err != nil {
		log.Fatalf("Unable to format masquerades.go: %s", err)
	}
	generateTemplate(model, proxiedSitesTmpl, "../config/proxiedsites.go")
	_, err = run("gofmt", "-w", "../config/proxiedsites.go")
	if err != nil {
		log.Fatalf("Unable to format proxiedsites.go: %s", err)
	}
	generateTemplate(model, fallbacksTmpl, "../config/fallbacks.go")
	_, err = run("gofmt", "-w", "../config/fallbacks.go")
	if err != nil {
		log.Fatalf("Unable to format fallbacks.go: %s", err)
	}
}

func loadDomains() {
	if *domainsFile == "" {
		log.Error("Please specify a domains file")
		flag.Usage()
		os.Exit(2)
	}
	domainsBytes, err := ioutil.ReadFile(*domainsFile)
	if err != nil {
		log.Fatalf("Unable to read domains file at %s: %s", *domainsFile, err)
	}
	domains = strings.Split(string(domainsBytes), "\n")
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
	err = json.Unmarshal(fallbacksBytes, &fallbacks)
	if err != nil {
		log.Fatalf("Unable to unmarshal json from %v: %v", *fallbacksFile, err)
	}
}

func loadTemplate(name string) string {
	bytes, err := ioutil.ReadFile(name)
	if err != nil {
		log.Fatalf("Unable to load template %s: %s", name, err)
	}
	return string(bytes)
}

func feedDomains() {
	wg.Add(numberOfWorkers)
	for i := 0; i < numberOfWorkers; i++ {
		go grabCerts()
	}

	for _, domain := range domains {
		domainsCh <- domain
	}
	close(domainsCh)
	wg.Wait()
	close(masqueradesCh)
}

// grabCerts grabs certificates for the domains received on domainsCh and sends
// *masquerades to masqueradesCh.
func grabCerts() {
	defer wg.Done()

	for domain := range domainsCh {
		_, blacklisted := blacklist[domain]
		if blacklisted {
			log.Tracef("Domain %s is blacklisted, skipping", domain)
			continue
		}
		log.Tracef("Grabbing certs for domain: %s", domain)
		cwt, err := tlsdialer.DialForTimings(&net.Dialer{
			Timeout: 10 * time.Second,
		}, "tcp", domain+":443", false, nil)
		if err != nil {
			log.Errorf("Unable to dial domain %s: %s", domain, err)
			continue
		}
		cwt.Conn.Close()
		chain := cwt.VerifiedChains[0]
		rootCA := chain[len(chain)-1]
		rootCert, err := keyman.LoadCertificateFromX509(rootCA)
		if err != nil {
			log.Errorf("Unablet to load keyman certificate: %s", err)
			continue
		}
		ca := &castat{
			CommonName: rootCA.Subject.CommonName,
			Cert:       strings.Replace(string(rootCert.PEMEncoded()), "\n", "\\n", -1),
		}
		masqueradesCh <- &masquerade{
			Domain:    domain,
			IpAddress: cwt.ResolvedAddr.IP.String(),
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

func buildModel(cas map[string]*castat, masquerades []*masquerade) map[string]interface{} {
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
	for _, fb := range fallbacks {
		ip := fb["ip"].(string)
		if fb["pt"] != nil {
			log.Debugf("Skipping fallback %v because it has pluggable transport enabled", ip)
			continue
		}

		cert := fb["cert"].(string)
		// Replace newlines in cert with newline literals
		fb["cert"] = strings.Replace(cert, "\n", "\\n", -1)

		// Test connectivity
		info := &client.ChainedServerInfo{
			Addr:      ip + ":443",
			Cert:      cert,
			AuthToken: fb["auth_token"].(string),
			Pipelined: true,
		}
		dialer, err := info.Dialer()
		if err != nil {
			log.Debugf("Skipping fallback %v because of error building dialer: %v", ip, err)
			continue
		}
		conn, err := dialer.Dial("tcp", "http://www.google.com")
		if err != nil {
			log.Debugf("Skipping fallback %v because dialing Google failed: %v", ip, err)
			continue
		}
		conn.Close()

		// Use this fallback
		fbs = append(fbs, fb)
	}
	return map[string]interface{}{
		"cas":          casList,
		"masquerades":  masquerades,
		"proxiedsites": ps,
		"fallbacks":    fbs,
	}
}

func generateTemplate(model map[string]interface{}, tmplString string, filename string) {
	tmpl, err := template.New(filename).Parse(tmplString)
	if err != nil {
		log.Errorf("Unable to parse template: %s", err)
		return
	}
	out, err := os.Create(filename)
	if err != nil {
		log.Errorf("Unable to create %s: %s", filename, err)
		return
	}
	defer out.Close()
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

type ByDomain []*masquerade

func (a ByDomain) Len() int           { return len(a) }
func (a ByDomain) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByDomain) Less(i, j int) bool { return a[i].Domain < a[j].Domain }

type ByFreq []*castat

func (a ByFreq) Len() int           { return len(a) }
func (a ByFreq) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByFreq) Less(i, j int) bool { return a[i].freq > a[j].freq }
