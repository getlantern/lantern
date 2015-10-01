package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"text/template"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/golog"
	"github.com/getlantern/yaml"
)

const (
	numberOfWorkers = 50
	ftVersionFile   = `https://raw.githubusercontent.com/firetweet/downloads/master/version.txt`
)

var (
	help            = flag.Bool("help", false, "Get usage help")
	masqueradesFile = flag.String("masquerades", "", "Path to file containing list of pasquerades to use, with one space-separated 'ip domain' pair per line (e.g. masquerades.txt)")
	blacklistFile   = flag.String("blacklist", "", "Path to file containing list of blacklisted domains, which will be excluded from the configuration even if present in the masquerades file (e.g. blacklist.txt)")
	proxiedSitesDir = flag.String("proxiedsites", "proxiedsites", "Path to directory containing proxied site lists, which will be combined and proxied by Lantern")
	minFreq         = flag.Float64("minfreq", 3.0, "Minimum frequency (percentage) for including CA cert in list of trusted certs, defaults to 3.0%")

	// Note - you can get the content for the fallbacksFile from https://lanternctrl1-2.appspot.com/listfallbacks
	fallbacksFile = flag.String("fallbacks", "fallbacks.yaml", "File containing json array of fallback information")
)

var (
	log = golog.LoggerFor("genconfig")

	//fallbacks []map[string]interface{}
	//fallbacks []map[string]string
	fallbacks map[string]*client.ChainedServerInfo

	inputCh = make(chan string)
	wg      sync.WaitGroup
)

type filter map[string]bool

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

	loadFallbacks()

	fallbacksTmpl := loadTemplate("fallbacks.go.tmpl")

	model := buildModel()

	generateTemplate(model, fallbacksTmpl, "../config/fallbacks.go")
	_, err := run("gofmt", "-w", "../config/fallbacks.go")
	if err != nil {
		log.Fatalf("Unable to format fallbacks.go: %s", err)
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
		return
	}
	//log.Debugf("Read bytes: %v", string(fallbacksBytes))
	err = yaml.Unmarshal(fallbacksBytes, &fallbacks)
	log.Debugf("Found %v fallbacks", len(fallbacks))
	if err != nil {
		log.Fatalf("Unable to unmarshal yaml from %v: %v", *fallbacksFile, err)
	} else {
		log.Debugf("fallbacks %v", fallbacks)
	}
}

func buildModel() map[string]interface{} {
	fbs := make([]map[string]interface{}, 0, len(fallbacks))
	for _, f := range fallbacks {
		fb := make(map[string]interface{})
		fb["ip"] = f.Addr
		fb["auth_token"] = f.AuthToken

		cert := f.Cert
		// Replace newlines in cert with newline literals
		fb["cert"] = strings.Replace(cert, "\n", "\\n", -1)

		info := f
		dialer, err := info.Dialer()
		if err != nil {
			log.Debugf("Skipping fallback %v because of error building dialer: %v", f.Addr, err)
			continue
		}
		conn, err := dialer.Dial("tcp", "http://www.google.com")
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
	return map[string]interface{}{
		"fallbacks": fbs,
	}
}

func loadTemplate(name string) string {
	bytes, err := ioutil.ReadFile(name)
	if err != nil {
		log.Fatalf("Unable to load template %s: %s", name, err)
	}
	return string(bytes)
}

/*
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
*/

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

/*
type ByDomain []*masquerade

func (a ByDomain) Len() int           { return len(a) }
func (a ByDomain) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByDomain) Less(i, j int) bool { return a[i].Domain < a[j].Domain }

type ByFreq []*castat

func (a ByFreq) Len() int           { return len(a) }
func (a ByFreq) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ByFreq) Less(i, j int) bool { return a[i].freq > a[j].freq }
*/
