// peerscanner is a program that maintains entries in CDN and DNS services
// based on whether or not the corresponding Lantern servers are currently
// online. Online status is determined based on whether or not we can
// successfully proxy requests to popular sites like www.google.com in a
// reasonable amount of time via each host.
//
// Peers are registered and unregistered via a web-based API (see file web.go).
//
// Each host is modeled as an actor with its own goroutine that constantly
// tests connectivity via the host (see file host.go).
//
// For each host, various CDN and DNS entries are managed:
//   - Cloudflare round-robin DNS+CDN entries.  Each server has an A entry with
//     the name "roundrobin.getiantem.org"[1] and its IP, with CDN functionality
//     activated ("orange cloud").
//   - A Cloudflare DNS+CDN entry ("orange cloud"), specific to each server.
//     This is used for sticky routing when domain fronting via Cloudflare.
//   - A DNSimple round-robin DNS entry ("roundrobin.flashlightproxy.org" [1]).
//     This has no CDN functionality itself.
//   - A DNSimple DNS entry specific to each server.
//   - A Cloudfront distribution that points to the previous one.
//
// Whenever peerscanner learns of a new server, it adds an entry of each kind
// above.  Whenever peerscanner finds a server is offline, it deletes the round
// robin entries, but not the server specific ones, nor the Cloudfront
// distribution.
//
// [1] Peerscanner used to manage, and may manage again in the future, servers
//     running on users' computers (give mode peers).  For this reason,
//     a "fallbacks.(getiantem|flashlightproxy).org" round-robin is currently
//     being maintained too.  Also, the ".(getiantem|flashlightproxy).org" parts
//     are configurable via the -cfldomain and -dspdomain command line
//     arguments.
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
	"github.com/getlantern/go-dnsimple/dnsimple"
	"github.com/getlantern/golog"
	"github.com/getlantern/peerscanner/cfl"
	"github.com/getlantern/peerscanner/cfr"
	"github.com/getlantern/peerscanner/dsp"
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
	dspdomain  = flag.String("dspdomain", "flashlightproxy.org", "DNSimple domain, defaults to flashlightproxy.org")
	cpuprofile = flag.String("cpuprofile", "", "(optional) specify the name of a file to which to write cpu profiling info")
	memprofile = flag.String("memprofile", "", "(optional) specify the name of a file to which to write memory profiling info")

	cflid   = os.Getenv("CFL_ID")
	cflkey  = os.Getenv("CFL_KEY")
	cflutil *cfl.Util

	cfrid   = os.Getenv("CFR_ID")
	cfrkey  = os.Getenv("CFR_KEY")
	cfrutil *cloudfront.CloudFront

	dspid   = os.Getenv("DSP_ID")
	dspkey  = os.Getenv("DSP_KEY")
	dsputil *dsp.Util

	hosts      map[string]*host
	hostsMutex sync.Mutex
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
	connectToDnsimple()

	var err error
	hosts, err = loadHosts()
	if err != nil {
		log.Fatal(err)
	}

	startHttp()
}

func parseFlags() {
	flag.Parse()
	if cflid == "" {
		log.Fatal("Please specify a CFL_ID environment variable")
	}
	if cflkey == "" {
		log.Fatal("Please specify a CFL_KEY environment variable")
	}
	if cfrid == "" {
		log.Fatal("Please specify a CFR_ID environment variable")
	}
	if cfrkey == "" {
		log.Fatal("Please specify a CFR_KEY environment variable")
	}
	if dspid == "" {
		log.Fatal("Please specify a DSP_ID environment variable")
	}
	if dspkey == "" {
		log.Fatal("Please specify a DSP_KEY environment variable")
	}
}

func connectToCloudFlare() {
	log.Debug("Connecting to CloudFlare ...")
	cflutil = cfl.New(*cfldomain, cflid, cflkey)
}

func connectToCloudFront() {
	log.Debug("Connecting to CloudFront ...")
	cfrutil = cfr.New(cfrid, cfrkey, nil)
}

func connectToDnsimple() {
	log.Debug("Connecting to DNSimple ...")
	dsputil = dsp.New(*dspdomain, dspid, dspkey)
}

/*******************************************************************************
 * Functions for managing map of hosts
 ******************************************************************************/

// loadHosts loads the initial list of hosts based on the existing entries in
// the CDN and DNS services we manage
func loadHosts() (map[string]*host, error) {

	log.Debug("Loading existing CloudFlare records ...")
	cflRecs, err := cflutil.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Unable to load Cloudflare records: %v", err)
	}
	log.Debugf("Loaded %d existing Cloudflare records", len(cflRecs))

	log.Debug("Loading existing DNSimple records ...")
	dspRecs, err := dsputil.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Unable to load DNSimple records: %v", err)
	}
	log.Debugf("Loaded %d existing DNSimple records", len(dspRecs))

	dists, err := cfr.ListDistributions(cfrutil)
	if err != nil {
		return nil, fmt.Errorf("Unable to load cloudfront distributions: %v", err)
	}
	log.Debugf("Loaded %d existing distributions", len(dists))

	// Collect round-robin entries in Cloudflare
	cflGroups := make(map[string]map[string]*cloudflare.Record, 0)
	addToCflGroup := func(name string, r cloudflare.Record) {
		log.Debugf("Adding to %v: %v", name, r.Value)
		g := cflGroups[name]
		if g == nil {
			g = make(map[string]*cloudflare.Record, 1)
			cflGroups[name] = g
		}
		g[r.Value] = &r
	}

	// Collect round-robin entries in DNSimple
	dspGroups := make(map[string]map[string]*dnsimple.Record, 0)
	addToDspGroup := func(name string, r dnsimple.Record) {
		log.Debugf("Adding to %v: %v", name, r.Content)
		g := dspGroups[name]
		if g == nil {
			g = make(map[string]*dnsimple.Record, 1)
			dspGroups[name] = g
		}
		g[r.Content] = &r
	}

	// Build map of existing hosts
	preHosts := make(map[string]*host)
	addHost := func(name string, ip string, cflRec *cloudflare.Record, dspRec *dnsimple.Record) {
		h := preHosts[ip]
		if h == nil {
			h = &host{name: name, ip: ip}
			preHosts[ip] = h
		}
		if cflRec != nil {
			h.cflRecord = cflRec
		}
		if dspRec != nil {
			h.dspRecord = dspRec
		}
	}

	// Look through Cloudflare records to find peers, fallbacks and groups
	for _, r := range cflRecs {
		if isFallback(r.Name) {
			log.Debugf("Adding fallback: %v", r.Name)
			addHost(r.Name, r.Value, &r, nil)
		} else if isPeer(r.Name) {
			log.Debugf("Not adding peer: %v", r.Name)
		} else if r.Name == RoundRobin {
			addToCflGroup(RoundRobin, r)
		} else if r.Name == Fallbacks {
			addToCflGroup(Fallbacks, r)
		} else if r.Name == Peers {
			addToCflGroup(Peers, r)
		} else if strings.HasSuffix(r.Name, ".fallbacks") {
			addToCflGroup(r.Name, r)
		} else {
			log.Tracef("Unrecognized Cloudflare record: %v", r.FullName)
		}
	}

	// Look through DNSimple records to find peers, fallbacks and groups
	for _, r := range dspRecs {
		if isFallback(r.Name) {
			log.Debugf("Adding fallback: %v", r.Name)
			addHost(r.Name, r.Content, nil, &r)
		} else if isPeer(r.Name) {
			log.Debugf("Not adding peer: %v", r.Name)
		} else if r.Name == RoundRobin {
			addToDspGroup(RoundRobin, r)
		} else if r.Name == Fallbacks {
			addToDspGroup(Fallbacks, r)
		} else if r.Name == Peers {
			addToDspGroup(Peers, r)
		} else if strings.HasSuffix(r.Name, ".fallbacks") {
			addToDspGroup(r.Name, r)
		} else {
			log.Tracef("Unrecognized DNSimple record: %v", r.Name)
		}
	}

	hostsByName := make(map[string]*host)
	hostsByIp := make(map[string]*host)
	for _, pre := range preHosts {
		h := newHost(pre.name, pre.ip, "", pre.cflRecord, pre.dspRecord)
		hostsByName[h.name] = h
		hostsByIp[h.ip] = h
	}

	for _, d := range dists {
		h, found := hostsByName[d.InstanceId]
		if found {
			h.cfrDist = d
		}
	}

	// Update hosts with Cloudflare group info
	for _, h := range hostsByIp {
		for _, hg := range h.cflGroups {
			g, found := cflGroups[hg.subdomain]
			if found {
				hg.existing = g[h.ip]
				delete(g, h.ip)
			}
		}
		// Don't accept round robins unless we have a working Cloudfront
		// distribution
		if h.cfrDistReady() {
			for _, hg := range h.dspGroups {
				g, found := dspGroups[hg.subdomain]
				if found {
					hg.existing = g[h.ip]
					delete(g, h.ip)
				}
			}
		}
	}

	var wg sync.WaitGroup

	// Remove items from rotation that don't have a corresponding host
	for k, g := range cflGroups {
		for _, r := range g {
			wg.Add(1)
			go removeCflRecord(&wg, k, r)
		}
	}
	for k, g := range dspGroups {
		for _, r := range g {
			wg.Add(1)
			go removeDspRecord(&wg, k, r)
		}
	}

	wg.Wait()

	// Start hosts
	for _, h := range hostsByIp {
		go h.run()
	}

	return hostsByIp, nil
}

func removeCflRecord(wg *sync.WaitGroup, k string, r *cloudflare.Record) {
	log.Debugf("%v in %v is missing Cloudflare record, removing", r.Value, k)
	err := cflutil.DestroyRecord(r)
	if err != nil {
		log.Debugf("Unable to remove %v from Cloudflare's %v: %v", r.Value, k, err)
	}
	wg.Done()
}

func removeDspRecord(wg *sync.WaitGroup, k string, r *dnsimple.Record) {
	log.Debugf("%v in %v is missing DNSimple record, removing", r.Content, k)
	err := dsputil.DestroyRecord(r)
	if err != nil {
		log.Debugf("Unable to remove %v from DNSimple's %v: %v", r.Content, k, err)
	}
	wg.Done()
}

func getOrCreateHost(name string, ip string, port string) *host {
	hostsMutex.Lock()
	defer hostsMutex.Unlock()

	h := hosts[ip]
	if h == nil {
		h := newHost(name, ip, port, nil, nil)
		hosts[ip] = h
		go h.run()
		return h
	}
	h.reset(name)
	return h
}

func getHostByIp(ip string) *host {
	hostsMutex.Lock()
	defer hostsMutex.Unlock()
	return hosts[ip]
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
