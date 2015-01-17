package main

import (
	"fmt"
	"github.com/getlantern/cloudflare"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/peerscanner/common"
)

var (
	util *common.CloudFlareUtil

	testTimeout = 6 * time.Second
)

// group represents a group of hosts (e.g. roundrobin, fallbacks, peers)
type group struct {
	subdomain string
	existing  map[string]cloudflare.Record
}

// host represents a host entry in CloudFlare
type host struct {
	record       cloudflare.Record
	testAttempts int      // how many times to try proxying through this host
	groups       []*group // groups of which this host is a member
}

func main() {
	log.Println("Starting CloudFlare Flashlight Tests...")

	util = common.NewCloudFlareUtil()
	for {
		testHosts()
	}
}

func testHosts() {
	log.Println("Starting pass!")

	records, err := util.GetAllRecords()
	if err != nil {
		log.Println("Error retrieving record!", err)
		return
	}

	//log.Println("Loaded all records...", records.Response.Recs.Count)

	recs := records.Response.Recs.Records

	log.Println("Total records loaded: ", len(recs))

	// These are the groups of hosts across which we round-robin
	var (
		fallbacks  = &group{common.FALLBACKS, make(map[string]cloudflare.Record)}
		peers      = &group{common.PEERS, make(map[string]cloudflare.Record)}
		roundRobin = &group{common.ROUNDROBIN, make(map[string]cloudflare.Record)}
	)

	// Fallbacks are part of their own group plus the roundRobin group, peers
	// are only in their own group
	var (
		fallbackGroups = []*group{fallbacks, roundRobin}
		peerGroups     = []*group{peers}
	)

	hosts := make([]*host, 0)
	for _, record := range recs {
		// We just check the length of the subdomain here, which is the unique
		// peer GUID. While it's possible something else could have a subdomain
		// this long, it's unlikely.
		if isPeer(record) {
			//log.Println("PEER: ", record.Value)
			hosts = append(hosts, &host{record, 1, peerGroups})
		} else if strings.HasPrefix(record.Name, "fl-") {
			//log.Println("SERVER: ", record.Name, record.Value)
			hosts = append(hosts, &host{record, 10, fallbackGroups})
		} else if record.Name == common.ROUNDROBIN {
			//log.Println("IN ROUNDROBIN: ", record.Name, record.Value)
			roundRobin.addExisting(record)
		} else if record.Name == common.PEERS {
			//log.Println("IN PEERS ROUNDROBIN: ", record.Name, record.Value)
			peers.addExisting(record)
		} else if record.Name == common.FALLBACKS {
			//log.Println("IN FALLBACK ROUNDROBIN: ", record.Name, record.Value)
			fallbacks.addExisting(record)
		} else {
			//log.Println("UNKNOWN ENTRY: ", record.Name, record.Value)
		}
	}

	var wg sync.WaitGroup
	wg.Add(len(hosts))
	for _, host := range hosts {
		go host.test(&wg)
	}
	wg.Wait()

	log.Println("Pass complete")
}

// addExisting adds a record to the map of existing records
func (g *group) addExisting(r cloudflare.Record) {
	g.existing[r.Value] = r
}

// register registers a host with this group in CloudFlare if it isn't already
// registered
func (g *group) register(h *host) {
	// Check to see if the host is already in the round robin before making a call
	// to the CloudFlare API.
	_, alreadyRegistered := g.existing[h.record.Value]
	if !alreadyRegistered {
		log.Printf("Registering to %s: %s", g.subdomain, h.record.Value)
		cr := cloudflare.CreateRecord{Type: "A", Name: g.subdomain, Content: h.record.Value}
		rec, err := util.Client.CreateRecord(common.CF_DOMAIN, &cr)

		if err != nil {
			log.Printf("Could not register? : %s", err)
			return
		}

		// Note for some reason CloudFlare seems to ignore the TTL here.
		ur := cloudflare.UpdateRecord{Type: "A", Name: g.subdomain, Content: rec.Value, Ttl: "360", ServiceMode: "1"}

		err = util.Client.UpdateRecord(common.CF_DOMAIN, rec.Id, &ur)

		if err != nil {
			log.Printf("Could not register? : %s", err)
		}
	}
}

// unregister unregisters a host from this group in CloudFlare
func (g *group) unregister(h *host) {
	existing, registered := g.existing[h.record.Value]
	if registered {
		log.Printf("Unregistering from %s: %s", g.subdomain, h.record.Value)

		// Destroy the record in the roundrobin...
		util.Client.DestroyRecord(existing.Domain, existing.Id)
	}
}

// test tests to make sure that this host can proxy traffic and either adds or
// removes it from CloudFlare DNS depending on the result.
func (h *host) test(wg *sync.WaitGroup) {
	if h.isAbleToProxy() {
		for _, group := range h.groups {
			group.register(h)
		}
	} else {
		for _, group := range h.groups {
			group.unregister(h)
		}
	}
	wg.Done()
}

// isAbleToProxy checks whether we're able to proxy through this host, which
// might involve multiple checks. Note - when checking servers,  the danger
// here is that the server start failing because they're overloaded,
// we start a cascading failure effect where we kill the most overloaded
// servers and add their load to the remaining ones, thereby making it
// much more likely those will fail as well. Our approach should take
// this into account and should only kill servers if their failure rates
// are much higher than the others and likely leaving a reasonable number
// of servers in the mix no matter what.
func (h *host) isAbleToProxy() bool {
	for i := 0; i < h.testAttempts; i++ {
		if h.isAbleToProxyOnce() {
			// If we get a single success we can exit the loop and consider it a success.
			return true
		}
	}
	// If we get consecutive failures up to our threshhold, consider it a failure.
	return false
}

// isAbleToProxyOnce attempts to proxy a reguest through the host
func (h *host) isAbleToProxyOnce() bool {
	succeeded := make(chan bool)
	go func() {
		succeeded <- h.doIsAbleToProxyOnce()
	}()

	// Only allow up to testTimeout time for letting single request finish
	select {
	case success := <-succeeded:
		return success
	case <-time.After(testTimeout):
		return false
	}
}

func (h *host) doIsAbleToProxyOnce() bool {
	httpClient := clientFor(h.record.Name+".getiantem.org", common.MASQUERADE_AS, common.ROOT_CA)

	req, _ := http.NewRequest("GET", "http://www.google.com/humans.txt", nil)
	resp, err := httpClient.Do(req)
	//log.Println("Finished http call for ", rec.Value)
	if err != nil {
		fmt.Errorf("HTTP Error: %s", resp)
		log.Println("HTTP ERROR HITTING PEER: ", h.record.Value, err)
		return false
	} else {
		body, err := ioutil.ReadAll(resp.Body)
		defer resp.Body.Close()
		if err != nil {
			fmt.Errorf("HTTP Body Error: %s", body)
			log.Println("Error reading body for peer: ", h.record.Value)
			return false
		} else {
			//log.Printf("RESPONSE FOR PEER: %s, %s\n", rec.Value, body)
			return true
		}
	}
}

func isPeer(r cloudflare.Record) bool {
	// We just check the length of the subdomain here, which is the unique
	// peer GUID. While it's possible something else could have a subdomain
	// this long, it's unlikely.
	return len(r.Name) == 32
}

func clientFor(upstreamHost string, masqueradeHost string, rootCA string) *http.Client {

	serverInfo := &client.ServerInfo{
		Host:              upstreamHost,
		Port:              443,
		DialTimeoutMillis: 5000,
	}
	masquerade := &client.Masquerade{masqueradeHost, rootCA}
	httpClient := client.HttpClient(serverInfo, masquerade)

	return httpClient
}
