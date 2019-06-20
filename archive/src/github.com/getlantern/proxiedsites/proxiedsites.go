// proxiedsites manages a list of proxied sites, including a default set of
// sites (cloud) and user-applied customizations to that list. It provides an
// implementation of the http.Handler interface that serves up a PAC file based
// on the currently active proxied sites (cloud + additions - deletions).
package proxiedsites

import (
	"sort"
	"sync"

	"github.com/getlantern/golog"

	"github.com/fatih/set"
)

var (
	log = golog.LoggerFor("proxiedsites")

	cs       *configsets
	cfgMutex sync.RWMutex
)

// Delta represents modifications to the proxied sites list.
type Delta struct {
	Additions []string `json:"additions"`
	Deletions []string `json:"deletions"`
}

// Merge merges the given delta into the existing one.
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

// Config is the whole configuration for proxiedsites.
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
	set := set.NewNonTS()
	set.Add(is...)
	return set
}

// toStrings converts a set into a slice of strings
func toStrings(s set.Interface) []string {
	l := set.StringSlice(s)
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
	log.Debug("Applied updated configuration")
	log.Debugf("%d additions, %d deletions", len(delta.Additions), len(delta.Deletions))
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
