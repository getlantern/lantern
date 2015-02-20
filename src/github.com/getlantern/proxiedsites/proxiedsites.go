// proxiedsites manages a list of proxied sites, including a default set of
// sites (cloud) and user-applied customizations to that list. It provides an
// implementation of the http.Handler interface that serves up a PAC file based
// on the currently active proxied sites (cloud + additions - deletions).
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
	cs            *configsets
	pacFile       string
	cfgMutex      sync.RWMutex
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

func (d *Delta) Merge(n *Delta) {
	oadd := toSet(d.Additions)
	odel := toSet(d.Deletions)
	nadd := toSet(n.Additions)
	ndel := toSet(n.Deletions)

	// First remove new deletions from old adds and vice versa
	fadd := set.Difference(oadd, ndel)
	fdel := set.Difference(odel, nadd)

	// Now add new adds and deletions
	fadd = set.Union(fadd, nadd)
	fdel = set.Union(fdel, ndel)

	d.Additions = toStrings(fadd)
	d.Deletions = toStrings(fdel)
}

// Config is the whole configuration for a ProxiedSites.
type Config struct {
	// User customizations
	*Delta

	// Global list of white-listed sites
	Cloud []string
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
func toSet(s []string) set.Interface {
	if s == nil {
		return set.NewNonTS()
	}
	is := make([]interface{}, len(s))
	for i, s := range s {
		is[i] = s
	}
	return set.NewNonTS(is...)
}

// toStrings converts a set into a slice of strings
func toStrings(s set.Interface) []string {
	sl := s.List()
	l := make([]string, len(sl))
	for i, s := range sl {
		l[i] = s.(string)
	}
	sort.Strings(l)
	return l
}

// configsets is a version of a Config that uses sets instead of slices
type configsets struct {
	cloud      set.Interface
	add        set.Interface
	del        set.Interface
	active     set.Interface
	activeList []string
}

// calculateActive calculates the active sites for the given configsets and
// stores them in the active property.
func (cs *configsets) calculateActive() {
	cs.active = set.Difference(set.Union(cs.cloud, cs.add), cs.del)
	cs.activeList = toStrings(cs.active)
}

// equals checks whether this configsets is identical to some other configsets
func (cs *configsets) equals(other *configsets) bool {
	return cs.cloud.IsEqual(other.cloud) &&
		cs.add.IsEqual(other.add) &&
		cs.del.IsEqual(other.del)
}

// Configure applies the given configuration. If there were changes, a Delta is
// returned that includes the additions and deletions from the active list. If
// there were no changes, or the changes couldn't be applied, this method
// returns a nil Delta.
func Configure(cfg *Config) *Delta {
	newCS := cfg.toCS()
	if cs != nil && cs.equals(newCS) {
		log.Debug("Configuration unchanged")
		return nil
	}

	newPacFile, err := generatePACFile(newCS.activeList)
	if err != nil {
		log.Errorf("Error generating pac file, leaving configuration unchanged: %v", err)
		return nil
	}

	var delta *Delta
	if cs == nil {
		delta = &Delta{
			Additions: newCS.activeList,
		}
	} else {
		delta = &Delta{
			Additions: toStrings(set.Difference(newCS.active, cs.active)),
			Deletions: toStrings(set.Difference(cs.active, newCS.active)),
		}
	}
	cs = newCS
	pacFile = newPacFile
	log.Debug("Applied updated configuration")
	return delta
}

// ActiveDelta returns the active sites as a Delta of additions.
func ActiveDelta() *Delta {
	cfgMutex.RLock()
	d := &Delta{
		Additions: cs.activeList,
	}
	cfgMutex.RUnlock()
	return d
}

// ServePAC serves up the PAC file and can be used as an http.HandlerFunc
func ServePAC(resp http.ResponseWriter, req *http.Request) {
	resp.Header().Set("Content-Type", "application/x-ns-proxy-autoconfig")
	resp.WriteHeader(http.StatusOK)
	cfgMutex.RLock()
	resp.Write([]byte(pacFile))
	cfgMutex.RUnlock()
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
// func Update(cfg *Config) {

// 	for i := range cfg.Additions {
// 		log.Debugf("Adding site %s", cfg.Additions[i])
// 		addSet.Add(cfg.Additions[i])
// 		// remove any new sites from our deletions list
// 		// if they were previously added there
// 		delSet.Remove(cfg.Additions[i])
// 	}

// 	for i := range cfg.Deletions {

// 		if addSet.Has(cfg.Deletions[i]) {
// 			// if a new deletion was previously on our
// 			// additionss list, remove it here
// 			addSet.Remove(cfg.Deletions[i])
// 		}
// 		if cloudSet.Has(cfg.Deletions[i]) {
// 			// add to the delete list only if it's
// 			// already in the global list
// 			delSet.Add(cfg.Deletions[i])
// 		}
// 	}

// 	cfg.Deletions = set.StringSlice(delSet)
// 	cfg.Additions = set.StringSlice(set.Difference(addSet, cloudSet))

// 	entries = set.StringSlice(set.Difference(set.Union(cloudSet, addSet),
// 		delSet))
// 	go updatePacFile()
// }

// func GetConfig() *Config {
// 	return cfg
// }

// func GetPacFile() string {
// 	return PacFilePath
// }

// func SetPacFile(pacFile string) {
// 	PacFilePath = pacFile
// }

// func updatePacFile() (err error) {

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
// 	data["Entries"] = entries
// 	err = pacFile.template.Execute(pacFile.file, data)
// 	if err != nil {
// 		log.Errorf("Error generating updated PAC file: %s", err)
// 	}

// 	return err
// }

// func GetEntries() []string {
// 	return entries
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
// 			entries = []string{}
// 			return ps
// 		}

// 		// need to remove escapes
// 		// and convert the otto value into a string array
// 		re := regexp.MustCompile("(\\\\.)")
// 		list := re.ReplaceAllString(value.String(), ".")
// 		entries = strings.Split(list, ",")
// 		log.Debugf("List of proxied sites... %+v", entries)
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
