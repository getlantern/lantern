package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"strings"
	"sync"
	"text/template"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

const (
	numberOfWorkers = 50
)

var (
	help          = flag.Bool("help", false, "Get usage help")
	domainsFile   = flag.String("domains", "", "Path to file containing list of domains to use, with one domain per line (e.g. domains.txt)")
	blacklistFile = flag.String("blacklist", "", "Path to file containing list of blacklisted domains, which will be excluded from the configuration even if present in the domains file (e.g. blacklist.txt)")
	minFreq       = flag.Float64("minfreq", 3.0, "Minimum frequency (percentage) for including CA cert in list of trusted certs, defaults to 3.0%")
)

var (
	log = golog.LoggerFor("genconfig")

	domains   []string
	blacklist = make(map[string]bool)

	masqueradesTmpl string
	yamlTmpl        string

	domainsCh     = make(chan string)
	masqueradesCh = make(chan *masquerade)
	wg            sync.WaitGroup
)

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
	loadBlacklist()

	masqueradesTmpl = loadTemplate("masquerades.go.tmpl")
	yamlTmpl = loadTemplate("cloud.yaml.tmpl")

	go feedDomains()
	cas, masquerades := coalesceMasquerades()
	model := buildModel(cas, masquerades)
	generateTemplate(model, yamlTmpl, "cloud.yaml")
	generateTemplate(model, masqueradesTmpl, "../config/masquerades.go")
	_, err := run("gofmt", "-w", "../config/masquerades.go")
	if err != nil {
		log.Fatalf("Unable to format masquerades.go: %s", err)
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
	return map[string]interface{}{
		"cas":         casList,
		"masquerades": masquerades,
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
