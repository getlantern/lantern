// peerscanner is program that maintains proxy hosts in CloudFlare's DNS based
// on whether or not the peers are currently online. Online status is determined
// based on whether or not we can successfully proxy requests to popular sites
// like www.google.com in a reasonable amount of time via each host.
//
// Peers are registered and unregistered via a web-baesd API (see file web.go).
//
// Each host is modeled as an actor with its own goroutine that constantly
// tests connectivity via the host.
package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"strings"
	"sync"

	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
	"github.com/getlantern/peerscanner/cf"
	"github.com/getlantern/profiling"
)

const (
	RoundRobin = "roundrobin"
	Peers      = "peers"
	Fallbacks  = "fallbacks"
)

var (
	log = golog.LoggerFor("peerscanner")

	port       = flag.Int("port", 62443, "Port, defaults to 62443")
	cfdomain   = flag.String("cfdomain", "getiantem.org", "CloudFlare domain, defaults to getiantem.org")
	cpuprofile = flag.String("cpuprofile", "", "(optional) specify the name of a file to which to write cpu profiling info")
	memprofile = flag.String("memprofile", "", "(optional) specify the name of a file to which to write memory profiling info")
	cfuser     = os.Getenv("CF_USER")
	cfkey      = os.Getenv("CF_API_KEY")

	cfutil *cf.Util

	hostsByName map[string]*host
	hostsByIp   map[string]*host
	hostsMutex  sync.Mutex
)

func main() {
	numCores := runtime.NumCPU()
	log.Debugf("Using all %d cores", numCores)
	runtime.GOMAXPROCS(numCores)

	parseFlags()

	finishProfiling := profiling.Start(*cpuprofile, *memprofile)
	defer finishProfiling()

	connectToCloudFlare()

	var err error
	hostsByIp, err = loadHosts()
	if err != nil {
		log.Fatal(err)
	}

	startHttp()
}

func parseFlags() {
	flag.Parse()
	if cfuser == "" {
		log.Fatal("Please specify a CF_USER environment variable")
	}
	if cfkey == "" {
		log.Fatal("Please specify a CF_API_KEY environment variable")
	}
}

func connectToCloudFlare() {
	log.Debug("Connecting to CloudFlare ...")

	var err error
	cfutil, err = cf.New(*cfdomain, cfuser, cfkey)
	if err != nil {
		log.Fatalf("Unable to create CloudFlare utility: %v", err)
	}
}

/*******************************************************************************
 * Functions for managing map of hosts
 ******************************************************************************/

// loadHosts loads the initial list of hosts based on what's in CloudFlare's
// DNS at startup.
func loadHosts() (map[string]*host, error) {
	log.Debug("Loading existing hosts from CloudFlare ...")

	recs, err := cfutil.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Unable to load hosts: %v", err)
	}

	// Keep track of different groups of hosts
	groups := map[string]map[string]*cloudflare.Record{
		RoundRobin: make(map[string]*cloudflare.Record),
		Fallbacks:  make(map[string]*cloudflare.Record),
		Peers:      make(map[string]*cloudflare.Record),
	}

	addToGroup := func(name string, r cloudflare.Record) {
		log.Tracef("Adding to %v: %v", name, r.Value)
		groups[name][r.Value] = &r
	}

	// Build map of existing hosts
	hosts := make(map[string]*host)

	addHost := func(r cloudflare.Record) {
		h := newHost(r.Name, r.Value, &r)
		hosts[h.ip] = h
	}

	// Look through all records to find peers, fallbacks and groups
	for _, r := range recs {
		// We just check the length of the subdomain here, which is the unique
		// peer GUID. While it's possible something else could have a subdomain
		// this long, it's unlikely.
		if isPeer(r.Name) {
			log.Tracef("Adding peer: %v", r.Name)
			addHost(r)
		} else if isFallback(r.Name) {
			log.Tracef("Adding fallback: %v", r.Name)
			addHost(r)
		} else if r.Name == RoundRobin {
			addToGroup(RoundRobin, r)
		} else if r.Name == Fallbacks {
			addToGroup(Fallbacks, r)
		} else if r.Name == Peers {
			addToGroup(Peers, r)
		} else {
			log.Tracef("Unrecognized record: %v", r.FullName)
		}
	}

	// Update hosts with group info
	for _, h := range hosts {
		for _, hg := range h.groups {
			g, found := groups[hg.subdomain]
			if found {
				hg.existing = g[h.ip]
				delete(g, h.ip)
			}
		}
	}

	// Remove items from rotation that don't have a corresponding host
	var wg sync.WaitGroup
	for k, g := range groups {
		for _, r := range g {
			wg.Add(1)
			go removeFromRotation(&wg, k, r)
		}
	}
	wg.Wait()

	// Start hosts
	for _, h := range hosts {
		h.run()
	}

	return hosts, nil
}

func removeFromRotation(wg *sync.WaitGroup, k string, r *cloudflare.Record) {
	log.Debugf("%v in %v is missing host, removing from rotation", r.Value, k)
	err := cfutil.DestroyRecord(r)
	if err != nil {
		log.Debugf("Unable to remove %v from %v: %v", r.Value, k, err)
	}
	wg.Done()
}

func getOrCreateHost(name string, ip string) *host {
	hostsMutex.Lock()
	defer hostsMutex.Unlock()

	h := hostsByIp[ip]
	if h == nil {
		h := newHost(name, ip, nil)
		hostsByIp[ip] = h
		go h.run()
		return h
	}
	h.reset(name)
	return h
}

func getHostByIp(ip string) *host {
	hostsMutex.Lock()
	defer hostsMutex.Unlock()
	return hostsByIp[ip]
}

func removeHost(h *host) {
	hostsMutex.Lock()
	delete(hostsByIp, h.ip)
	defer hostsMutex.Unlock()
}

func isPeer(name string) bool {
	// We just check the length of the subdomain here, which is the unique
	// peer GUID. While it's possible something else could have a subdomain
	// this long, it's unlikely.
	// We also accept anything with a name beginning with peer- as a peer
	return len(name) == 32 || strings.Index(name, "peer-") == 0
}

func isFallback(name string) bool {
	return strings.HasPrefix(name, "fl-")
}
