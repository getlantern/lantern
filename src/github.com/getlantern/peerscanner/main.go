// main simply contains the primary web serving code that allows peers to
// register and unregister as give mode peers running within the Lantern
// network
package main

import (
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"./cf"
	"github.com/getlantern/cloudflare"
	"github.com/getlantern/golog"
)

const (
	MASQUERADE_AS = "cdnjs.com"
	ROOT_CA       = "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n"
	ROUNDROBIN    = "test_roundrobin"
	PEERS         = "test_peers"
	FALLBACKS     = "test_fallbacks"
)

var (
	log = golog.LoggerFor("peerscanner")

	port     = flag.Int("port", 62443, "Port, defaults to 62443")
	cfdomain = flag.String("cfdomain", "getiantem.org", "CloudFlare domain, defaults to getiantem.org")
	cfuser   = os.Getenv("CF_USER")
	cfkey    = os.Getenv("CF_API_KEY")

	cfutil *cf.Util
	hosts  map[string]*host
)

func main() {
	parseFlags()
	connectToCloudFlare()

	var err error
	hosts, err = loadHosts()
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
	var err error
	cfutil, err = cf.New(*cfdomain, cfuser, cfkey)
	if err != nil {
		log.Fatalf("Unable to create CloudFlare utility: %v", err)
	}
}

func loadHosts() ([]*host, error) {
	recs, err := cfutil.GetAllRecords()
	if err != nil {
		return nil, fmt.Errorf("Unable to load hosts: %v", err)
	}

	roundRobins := make(map[string]cloudflare.Record)
	fallbacks := make(map[string]cloudflare.Record)
	peers := make(map[string]cloudflare.Record)
	hosts := make([]*host, 0)

	addHost := func(r cloudflare.Record) {
		hosts[r.Name] = &host{record: r}
	}

	for _, record := range recs {
		// We just check the length of the subdomain here, which is the unique
		// peer GUID. While it's possible something else could have a subdomain
		// this long, it's unlikely.
		if isPeer(record.Name) {
			addHost(record)
		} else if isFallback(record.Name) {
			addHost(record)
		} else if record.Name == ROUNDROBIN {
			roundRobins[record.Value] = record
		} else if record.Name == FALLBACKS {
			fallbacks[record.Value] = record
		} else if record.Name == PEERS {
			peers[record.Value] = record
		} else {
			log.Tracef("Unrecognized record: %v", record.FullName)
		}
	}

	// Update hosts with rotation info
	for _, h := range hosts {
		ip := h.record.Value
		h.roundrobin = roundRobins[ip]
		h.fallbacks = fallbacks[ip]
		h.peers = peers[ip]
		delete(roundRobins, ip)
		delete(fallbacks, ip)
		delete(peers, ip)
	}

	// Remove items from rotation that don't have a corresponding host
	cleanupRotation(ROUNDROBIN, roundRobins)
	cleanupRotation(FALLBACKS, fallbacks)
	cleanupRotation(PEERS, peers)

	// Start processing hosts
	for _, h := range hosts {
		go h.run()
	}

	return hosts, nil
}

func cleanupRotation(rotation string, recs map[string]cloudflare.Record) {
	for _, r := range recs {
		log.Debugf("%v in %v is missing host, removing from rotation", r.Value, rotation)
		cf.RemoveIpFromRoundRobin(r.Value, rotation)
	}
}

func isPeer(name string) bool {
	// We just check the length of the subdomain here, which is the unique
	// peer GUID. While it's possible something else could have a subdomain
	// this long, it's unlikely.
	return len(name) == 32
}

func isFallback(name string) bool {
	return strings.HasPrefix(name, "fl-")
}
