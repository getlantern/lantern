// package proxiedsites is a module used to manage the list of sites
// being proxied by Lantern.
// when the list is modified using the Lantern UI, it propagates
// to the default YAML and PAC file configurations
package proxiedsites

import (
	"bytes"
	"fmt"
	"net/http"
	"sort"
	"sync"
	"text/template"

	"github.com/getlantern/golog"

	"gopkg.in/fatih/set.v0"
)

var (
	log = golog.LoggerFor("proxiedsites")

	parsedPacTmpl *template.Template
)

func init() {
	// Parse PACFile template on startup
	var err error
	parsedPacTmpl, err = template.New("pacfile").Parse(pactmpl)
	if err != nil {
		panic(fmt.Errorf("Could not parse PAC file template: %v", err))
	}
}

// Delta represents modifications to the proxied sites list.
type Delta struct {
	Additions []string `json:"Additions, omitempty"`
	Deletions []string `json:"Deletions, omitempty"`
}

// Config is the whole configuration for a ProxiedSites.
type Config struct {
	// User customizations
	Delta

	// Global list of white-listed sites
	Cloud []string `json:"-"`
}

// toCS converts this Config into a configsets
func (cfg *Config) toCS() *configsets {
	cs := &configsets{
		cloud: toSet(cfg.Cloud),
		add:   toSet(cfg.Delta.Additions),
		del:   toSet(cfg.Delta.Deletions),
	}
	cs.calculateActive()
	return cs
}

// toSet converts a slice of strings into a set
func toSet(s []string) *set.SetNonTS {
	if s == nil {
		return set.NewNonTS()
	}
	is := make([]interface{}, len(s))
	for i, s := range s {
		is[i] = s
	}
	return set.NewNonTS(is...)
}

// configsets is a version of a Config that uses sets instead of slices
type configsets struct {
	cloud  *set.SetNonTS
	add    *set.SetNonTS
	del    *set.SetNonTS
	active []string
}

// calculateActive calculates the active sites for the given configsets and
// stores them in the active property.
func (cs *configsets) calculateActive() {
	a := set.Difference(set.Union(cs.cloud, cs.add), cs.del)
	as := a.List()
	r := make([]string, len(as))
	for i, s := range as {
		r[i] = s.(string)
	}
	sort.Strings(r)
	cs.active = r
}

// equals checks whether this configsets is identical to some other configsets
func (cs *configsets) equals(other *configsets) bool {
	return cs.cloud.IsEqual(other.cloud) &&
		cs.add.IsEqual(other.add) &&
		cs.del.IsEqual(other.del)
}

// ProxiedSites manages a list of proxied sites, including a default set of
// sites (cloud) and user-applied customizations to that list. It implements the
// http.Handler interface in order to serve up a PAC file based on the currently
// active proxied sites (cloud + additions - deletions).
type ProxiedSites struct {
	cs       *configsets
	pacFile  string
	cfgMutex sync.RWMutex
}

// Configure applies the given configuration.
func (ps *ProxiedSites) Configure(cfg *Config) {
	newCS := cfg.toCS()
	if ps.cs != nil && ps.cs.equals(newCS) {
		log.Debug("Configuration unchanged")
		return
	}

	pacFile, err := generatePACFile(newCS.active)
	if err != nil {
		log.Errorf("Error generating pac file, leaving configuration unchanged: %v", err)
		return
	}

	ps.cs = newCS
	ps.pacFile = pacFile
	log.Debug("Applied updated configuration")
}

// ServeHTTP implements the http.Handler interface and serves up the PAC file.
func (ps *ProxiedSites) ServeHTTP(resp http.ResponseWriter, req *http.Request) {
	resp.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
	resp.WriteHeader(http.StatusOK)
	ps.cfgMutex.RLock()
	resp.Write([]byte(ps.pacFile))
	ps.cfgMutex.RUnlock()
}

// generatePACFile generates a PAC File from the given active sites.
func generatePACFile(activeSites []string) (string, error) {
	data := make(map[string]interface{}, 0)
	data["Entries"] = activeSites
	buf := bytes.NewBuffer(nil)
	err := parsedPacTmpl.Execute(buf, data)
	if err != nil {
		return "", fmt.Errorf("Error generating updated PAC file: %s", err)
	}
	return string(buf.Bytes()), nil
}

// // Composes the add and delete deltas
// // between a new proxiedsites and a previous proxiedsites instance
// func (prev *ProxiedSites) Diff(cur *ProxiedSites) *Config {

// 	addSet := set.Difference(set.Union(cur.cloudSet, cur.addSet),
// 		set.Union(prev.cloudSet, prev.addSet))

// 	delSet := set.Difference(cur.delSet, prev.delSet)

// 	additions := set.StringSlice(set.Difference(addSet, delSet))

// 	sort.Strings(additions)

// 	return &Config{
// 		Deltas: Deltas{
// 			Additions: additions,
// 			Deletions: set.StringSlice(delSet),
// 		},
// 	}
// }

// // Update modifies an existing ProxiedSites instance
// // to include new addition and deletion deltas sent from
// // the client
// func (ps *ProxiedSites) Update(cfg *Config) {

// 	for i := range cfg.Additions {
// 		log.Debugf("Adding site %s", cfg.Additions[i])
// 		ps.addSet.Add(cfg.Additions[i])
// 		// remove any new sites from our deletions list
// 		// if they were previously added there
// 		ps.delSet.Remove(cfg.Additions[i])
// 	}

// 	for i := range cfg.Deletions {

// 		if ps.addSet.Has(cfg.Deletions[i]) {
// 			// if a new deletion was previously on our
// 			// additionss list, remove it here
// 			ps.addSet.Remove(cfg.Deletions[i])
// 		}
// 		if ps.cloudSet.Has(cfg.Deletions[i]) {
// 			// add to the delete list only if it's
// 			// already in the global list
// 			ps.delSet.Add(cfg.Deletions[i])
// 		}
// 	}

// 	ps.cfg.Deletions = set.StringSlice(ps.delSet)
// 	ps.cfg.Additions = set.StringSlice(set.Difference(ps.addSet, ps.cloudSet))

// 	ps.entries = set.StringSlice(set.Difference(set.Union(ps.cloudSet, ps.addSet),
// 		ps.delSet))
// 	go ps.updatePacFile()
// }

// func (ps *ProxiedSites) GetConfig() *Config {
// 	return ps.cfg
// }

// func GetPacFile() string {
// 	return PacFilePath
// }

// func SetPacFile(pacFile string) {
// 	PacFilePath = pacFile
// }

// func (ps *ProxiedSites) updatePacFile() (err error) {

// 	pacFile := &PacFile{}

// 	pacFile.file, err = os.Create(PacFilePath)
// 	defer pacFile.file.Close()
// 	if err != nil {
// 		log.Errorf("Could not create PAC file")
// 		return
// 	}
// 	// parse the PAC file template
// 	pacFile.template, err = template.ParseFiles(PacTmpl)
// 	if err != nil {
// 		log.Errorf("Could not open PAC file template: %s", err)
// 		return
// 	}

// 	log.Debugf("Updating PAC file; path is %s", PacFilePath)
// 	pacFile.l.Lock()
// 	defer pacFile.l.Unlock()

// 	data := make(map[string]interface{}, 0)
// 	data["Entries"] = ps.entries
// 	err = pacFile.template.Execute(pacFile.file, data)
// 	if err != nil {
// 		log.Errorf("Error generating updated PAC file: %s", err)
// 	}

// 	return err
// }

// func (ps *ProxiedSites) GetEntries() []string {
// 	return ps.entries
// }

// func ParsePacFile() *ProxiedSites {
// 	ps := &ProxiedSites{}

// 	log.Debugf("PAC file found %s; loading entries..", PacFilePath)
// 	program, err := parser.ParseFile(nil, PacFilePath, nil, 0)
// 	// otto is a native JavaScript parser;
// 	// we just quickly parse the proxy domains
// 	// from the PAC file to
// 	// cleanly send in a JSON response
// 	vm := otto.New()
// 	_, err = vm.Run(program)
// 	if err != nil {
// 		log.Errorf("Could not parse PAC file %+v", err)
// 		return nil
// 	} else {
// 		value, _ := vm.Get("proxyDomains")
// 		log.Debugf("PAC entries %+v", value.String())
// 		if value.String() == "" {
// 			// no pac entries; return empty array
// 			ps.entries = []string{}
// 			return ps
// 		}

// 		// need to remove escapes
// 		// and convert the otto value into a string array
// 		re := regexp.MustCompile("(\\\\.)")
// 		list := re.ReplaceAllString(value.String(), ".")
// 		ps.entries = strings.Split(list, ",")
// 		log.Debugf("List of proxied sites... %+v", ps.entries)
// 	}
// 	return ps
// }

const pactmpl = `var proxyDomains = new Array();
var i=0;

{{ range $key := .Entries }}
proxyDomains[i++] = "{{ $key }}";{{ end }}

for(i in proxyDomains) {
    proxyDomains[i] = proxyDomains[i].split(/\./).join("\\.");
}

var proxyDomainsRegx = new RegExp("(" + proxyDomains.join("|") + ")$", "i");

function FindProxyForURL(url, host) {
    if( host == "localhost" ||
        host == "127.0.0.1") {
        return "DIRECT";
    }

    if (proxyDomainsRegx.exec(host)) {
        return "PROXY 127.0.0.1:8787; DIRECT";
    }

    return "DIRECT";
}
`
