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

	"github.com/getlantern/aws-sdk-go/gen/cloudfront"
	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
	"github.com/getlantern/peerscanner/cfl"
	"github.com/getlantern/peerscanner/cfr"
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
	cfldomain  = flag.String("cfldomain", "getiantem.org", "CloudFlare domain, defaults to getiantem.org")
	cpuprofile = flag.String("cpuprofile", "", "(optional) specify the name of a file to which to write cpu profiling info")
	memprofile = flag.String("memprofile", "", "(optional) specify the name of a file to which to write memory profiling info")
	cfluser    = os.Getenv("CFL_USER")
	cflkey     = os.Getenv("CFL_API_KEY")

	cflutil *cfl.Util

	cfrid  = os.Getenv("CFR_ID")
	cfrkey = os.Getenv("CFR_KEY")

	cfrutil *cloudfront.CloudFront

	//XXX DNSSimple credentials and *Util

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
	connectToCloudFront()

	var err error
	hostsByIp, err = loadHosts()
	if err != nil {
		log.Fatal(err)
	}

	startHttp()
}

func parseFlags() {
	flag.Parse()
	if cfluser == "" {
		log.Fatal("Please specify a CFL_USER environment variable")
	}
	if cflkey == "" {
		log.Fatal("Please specify a CFL_API_KEY environment variable")
	}
}

func connectToCloudFlare() {
	log.Debug("Connecting to CloudFlare ...")
	cflutil = cfl.New(*cfldomain, cfluser, cflkey)
}

func connectToCloudFront() {
	log.Debug("Connecting to CloudFront ...")
	cfrutil = cfr.New(cfrid, cfrkey, nil)
}

/*******************************************************************************
 * Functions for managing map of hosts
 ******************************************************************************/

// loadHosts loads the initial list of hosts based on what's in CloudFlare's
// DNS at startup.
func loadHosts() (map[string]*host, error) {
	log.Debug("Loading existing hosts from CloudFlare ...")

	recs, err := cflutil.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Unable to load hosts: %v", err)
	}
	log.Debugf("Loaded %d existing hosts", len(recs))

	// XXX: get all DNSSimple records

	dists, err := cfr.ListDistributions(cfrutil)
	if err != nil {
		return nil, fmt.Errorf("Unable to load cloudfront distributions: %v", err)
	}

	// Keep track of different groups of hosts
	// XXX: cflGroups vs dspGroups
	groups := make(map[string]map[string]*cloudflare.Record, 0)

	addToGroup := func(name string, r cloudflare.Record) {
		log.Debugf("Adding to %v: %v", name, r.Value)
		g := groups[name]
		if g == nil {
			g = make(map[string]*cloudflare.Record, 1)
			groups[name] = g
		}
		g[r.Value] = &r
	}

	// Build map of existing hosts
	hosts := make(map[string]*host)

	addHost := func(r cloudflare.Record) {
		h := newHost(r.Name, r.Value, &r)
		hosts[h.ip] = h
	}

	// Look through all records to find peers, fallbacks and groups
	// XXX: same for DNSSimple records.
	for _, r := range recs {
		if isFallback(r.Name) {
			log.Debugf("Adding fallback: %v", r.Name)
			addHost(r)
		} else if isPeer(r.Name) {
			log.Debugf("Not adding peer: %v", r.Name)
		} else if r.Name == RoundRobin {
			addToGroup(RoundRobin, r)
		} else if r.Name == Fallbacks {
			addToGroup(Fallbacks, r)
		} else if r.Name == Peers {
			addToGroup(Peers, r)
		} else if strings.HasSuffix(r.Name, ".fallbacks") {
			addToGroup(r.Name, r)
		} else {
			log.Tracef("Unrecognized record: %v", r.FullName)
		}
	}

	// XXX; Change it so hosts are keyed by non-qualified hostname
	for _, d := range dists {
		h, found := hosts[d.InstanceId]
		if found {
			h.cfrDist = d
		}
	}

	// XXX: Assign DNSSimple records

	// Update hosts with Cloudflare group info
	// XXX: same for DNSSimple
	for _, h := range hosts {
		for _, hg := range h.groups {
			g, found := groups[hg.subdomain]
			if found {
				hg.existing = g[h.ip]
				delete(g, h.ip)
			}
		}
	}

	var wg sync.WaitGroup

	// Remove items from rotation that don't have a corresponding host
	// XXX: same for DNSSimple, plus check that we have a Deployed distribution
	for k, g := range groups {
		for _, r := range g {
			wg.Add(1)
			go removeRecord(&wg, k, r)
		}
	}

	wg.Wait()

	// Start hosts
	for _, h := range hosts {
		go h.run()
	}

	return hosts, nil
}

func removeRecord(wg *sync.WaitGroup, k string, r *cloudflare.Record) {
	log.Debugf("%v in %v is missing host, removing", r.Value, k)
	err := cflutil.DestroyRecord(r)
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

func isPeer(name string) bool {
	// We just check the length of the subdomain here, which is the unique
	// peer GUID. While it's possible something else could have a subdomain
	// this long, it's unlikely.
	// We also accept anything with a name beginning with peer- as a peer
	return len(name) == 32 || strings.HasPrefix(name, "peer-")
}

func isFallback(name string) bool {
	return strings.HasPrefix(name, "fl-")
}
