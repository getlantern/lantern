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
