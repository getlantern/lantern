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
	"net/http/httputil"
	"net/url"
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
	ftVersionFile   = `https://raw.githubusercontent.com/firetweet/downloads/master/version.txt`
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
	ftVersion    string

	domainsCh     = make(chan string)
	masqueradesCh = make(chan *Masquerade)
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
	//loadProxiedSitesList()
	//loadBlacklist()
	//loadFallbacks()
	//loadFtVersion()

	masqueradesTmpl := loadTemplate("masquerades.go.tmpl")
	//proxiedSitesTmpl := loadTemplate("proxiedsites.go.tmpl")
	//fallbacksTmpl := loadTemplate("fallbacks.go.tmpl")
	//yamlTmpl := loadTemplate("cloud.yaml.tmpl")

	go feedDomains()
	cas, masquerades := coalesceMasquerades()
	model := buildModel(cas, masquerades)
	//generateTemplate(model, yamlTmpl, "cloud.yaml")
	generateTemplate(model, masqueradesTmpl, "../config/masquerades.go")
	_, err := run("gofmt", "-w", "../config/masquerades.go")
	if err != nil {
		log.Fatalf("Unable to format masquerades.go: %s", err)
	}
	/*
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
	*/
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
		if err := cwt.Conn.Close(); err != nil {
			log.Debugf("Error closing connection: %v", err)
		}
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
		masq := &Masquerade{
			Domain:    domain,
			IpAddress: cwt.ResolvedAddr.IP.String(),
			RootCA:    ca,
		}

		if verifyMasquerade(masq) {
			log.Debugf("MASQUERADE VERIFIED: %v", domain)
			masqueradesCh <- masq
		}
	}
}

func verifyMasquerade(masq *Masquerade) bool {
	httpClient := NewDirectDomainFronter(masq)
	country, ip, err := lookupIp(httpClient)
	if err != nil {
		log.Errorf("Could not lookup IP: %v", err)
		return false
	}
	log.Debugf("Got country %v and ip %v", country, ip)

	return len(country) > 1
}

func lookupIp(httpClient *http.Client) (string, string, error) {
	httpClient.Timeout = 60 * time.Second

	var err error
	var req *http.Request
	var resp *http.Response

	// Note this will typically be an HTTP client that uses direct domain fronting to
	// hit our server pool in the Netherlands.
	if req, err = http.NewRequest("HEAD", "http://nl.fallbacks.getiantem.org", nil); err != nil {
		return "", "", fmt.Errorf("Could not create request: %q", err)
	}

	if resp, err = httpClient.Do(req); err != nil {
		return "", "", fmt.Errorf("Could not get response from server: %q", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close reponse body: %v", err)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		if full, err := httputil.DumpResponse(resp, true); err != nil {
			log.Errorf("Could not read full response %v", err)
		} else {
			log.Errorf("Unexpected response to geo IP lookup: %v", string(full))
		}
		return "", "", fmt.Errorf("Unexpected response status %d", resp.StatusCode)
	}

	ip := resp.Header.Get("Lantern-Ip")
	country := resp.Header.Get("Lantern-Country")

	log.Debugf("Got IP and country: %v, %v", ip, country)
	return country, ip, nil
}

// DirectDomainTransport is a wrapper struct enabling us to modify the protocol of outgoing
// requests to make them all HTTP instead of potentially HTTPS, which breaks our particular
// implemenation of direct domain fronting.
type DirectDomainTransport struct {
	http.Transport
}

func (ddf *DirectDomainTransport) RoundTrip(req *http.Request) (resp *http.Response, err error) {
	// The connection is already encrypted by domain fronting.  We need to rewrite URLs starting
	// with "https://" to "http://", lest we get an error for doubling up on TLS.

	// The RoundTrip interface requires that we not modify the memory in the request, so we just
	// create a copy.
	norm := new(http.Request)
	*norm = *req // includes shallow copies of maps, but okay
	norm.URL = new(url.URL)
	*norm.URL = *req.URL
	norm.URL.Scheme = "http"
	return ddf.Transport.RoundTrip(norm)
}

// Masquerade contains the data for a single masquerade host, including
// the domain and the root CA.
type Masquerade struct {
	// Domain: the domain to use for domain fronting
	Domain string

	// IpAddress: pre-resolved ip address to use instead of Domain (if
	// available)
	IpAddress string

	RootCA *castat
}

// Creates a new http.Client that does direct domain fronting.
func NewDirectDomainFronter(masquerade *Masquerade) *http.Client {
	log.Debugf("Creating new direct domain fronter.")
	return &http.Client{
		Transport: &DirectDomainTransport{
			Transport: http.Transport{
				Dial: func(network, addr string) (net.Conn, error) {
					log.Debugf("Dialing %s with direct domain fronter", addr)
					return dialServerWith(masquerade)
				},
				TLSHandshakeTimeout: 40 * time.Second,
				DisableKeepAlives:   true,
			},
		},
	}
}

func dialServerWith(masquerade *Masquerade) (net.Conn, error) {
	dialTimeout := 30 * time.Second

	// Note - we need to suppress the sending of the ServerName in the client
	// handshake to make host-spoofing work with Fastly.  If the client Hello
	// includes a server name, Fastly checks to make sure that this matches the
	// Host header in the HTTP request and if they don't match, it returns
	// a 400 Bad Request error.
	sendServerNameExtension := false

	cwt, err := tlsdialer.DialForTimings(
		&net.Dialer{
			Timeout: dialTimeout,
		},
		"tcp",
		addressForServer(masquerade),
		sendServerNameExtension,
		tlsConfig(masquerade))

	if err != nil && masquerade != nil {
		err = fmt.Errorf("Unable to dial masquerade %s: %s", masquerade.Domain, err)
	}
	return cwt.Conn, err
}

// Get the address to dial for reaching the server
//func addressForServer(masquerade *Masquerade) string {
//	return fmt.Sprintf("%s:%d", masquerade.IpAddress, 443)
//}

func addressForServer(masquerade *Masquerade) string {
	return fmt.Sprintf("%s:%d", serverHost(masquerade), 443)
}

func serverHost(masquerade *Masquerade) string {
	if masquerade.IpAddress != "" {
		return masquerade.IpAddress
	}
	return masquerade.Domain
}

// tlsConfig builds a tls.Config for dialing the upstream host. Constructed
// tls.Configs are cached on a per-masquerade basis to enable client session
// caching and reduce the amount of PEM certificate parsing.
func tlsConfig(masquerade *Masquerade) *tls.Config {
	/*
			caCert, err := keyman.LoadCertificateFromPEMBytes([]byte(masquerade.RootCA.Cert))
		if err != nil {
			return nil
		}
	*/
	serverName := masquerade.Domain
	tlsConfig := &tls.Config{
		ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		InsecureSkipVerify: true,
		ServerName:         serverName,
		//		RootCAs:            caCert.PoolContainingCert(),
	}

	return tlsConfig
}

func coalesceMasquerades() (map[string]*castat, []*Masquerade) {
	count := 0
	allCAs := make(map[string]*castat)
	allMasquerades := make([]*Masquerade, 0)
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
	trustedMasquerades := make([]*Masquerade, 0)
	for _, masquerade := range allMasquerades {
		_, caFound := trustedCAs[masquerade.RootCA.Cert]
		if caFound {
			trustedMasquerades = append(trustedMasquerades, masquerade)
		}
	}

	return trustedCAs, trustedMasquerades
}

func buildModel(cas map[string]*castat, masquerades []*Masquerade) map[string]interface{} {
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
		addr := fb["addr"].(string)
		cert := fb["cert"].(string)
		// Replace newlines in cert with newline literals
		fb["cert"] = strings.Replace(cert, "\n", "\\n", -1)

		// Test connectivity
		info := &client.ChainedServerInfo{
			Addr:      addr,
			Cert:      cert,
			AuthToken: fb["authtoken"].(string),
			Pipelined: true,
		}
		dialer, err := info.Dialer()
		if err != nil {
			log.Debugf("Skipping fallback %v because of error building dialer: %v", addr, err)
			continue
		}
		conn, err := dialer.Dial("tcp", "http://www.google.com")
		if err != nil {
			log.Debugf("Skipping fallback %v because dialing Google failed: %v", addr, err)
			continue
		}
		if err := conn.Close(); err != nil {
			log.Debugf("Error closing connection: %v", err)
		}

		// Use this fallback
		fbs = append(fbs, fb)
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

type ByDomain []*Masquerade

func (a ByDomain) Len() int           { return len(a) }
func (a ByDomain) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByDomain) Less(i, j int) bool { return a[i].Domain < a[j].Domain }

type ByFreq []*castat

func (a ByFreq) Len() int           { return len(a) }
func (a ByFreq) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByFreq) Less(i, j int) bool { return a[i].freq > a[j].freq }
