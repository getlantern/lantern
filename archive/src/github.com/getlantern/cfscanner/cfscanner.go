package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
)

var (
	log        = golog.LoggerFor("cfscanner")
	help       = flag.Bool("help", false, "Get usage help")
	numWorkers = flag.Int("workers", 1, "Number of concurrent workers")
	out        = flag.String("o", "masquerades.txt", "Output file")
)

func webSlurp(url string) ([]byte, error) {
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("Error fetching IP list: %v", err)
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Error trying to read response: %v", err)
	}
	return body, nil
}

type castat struct {
	CommonName string
	Cert       string
	freq       float64
}

func main() {
	main_()
}

type cloudfrontPrefix struct {
	Ip_prefix string
	Region    string
	Service   string
}

func main_() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	bs, err := webSlurp("https://ip-ranges.amazonaws.com/ip-ranges.json")
	if err != nil {
		log.Fatal(err)
	}
	var objmap map[string]*json.RawMessage
	if err = json.Unmarshal(bs, &objmap); err != nil {
		log.Fatal(err)
	}
	var prefixes []cloudfrontPrefix
	if err = json.Unmarshal(*objmap["prefixes"], &prefixes); err != nil {
		log.Fatal(err)
	}

	ipch := make(chan string)
	ipwg := sync.WaitGroup{}

	for _, prefix := range prefixes {
		if prefix.Service == "CLOUDFRONT" {
			ipwg.Add(1)
			go enumerateRange(prefix.Ip_prefix, ipch, &ipwg)
		}
	}

	// Send death pill to all workers when we're done feeding IPs.
	go func() {
		ipwg.Wait()
		for i := 0; i < *numWorkers; i++ {
			ipch <- ""
		}
	}()

	reswg := sync.WaitGroup{}
	reswg.Add(*numWorkers)
	resch := make(chan string)
	go func() {
		reswg.Wait()
		resch <- ""
	}()
	for i := 0; i < *numWorkers; i++ {
		go checkIPs(ipch, resch, &reswg)
	}

	f, err := os.Create(*out)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	for result := range resch {
		if result == "" {
			fmt.Println("Done!")
			break
		}
		fmt.Printf("*** Successfully verified %v\n", result)
		_, err = f.WriteString(result + "\n")
		if err != nil {
			log.Fatal(err)
		}
		f.Sync()
	}
}

func checkIPs(ipch <-chan string, resch chan<- string, wg *sync.WaitGroup) {
	defer wg.Done()
	for ip := range ipch {
		if ip == "" {
			break
		}
		domain, err := checkIP(ip)
		if err == nil {
			resch <- domain
		} else {
			log.Errorf("Error checking %v: %v\n", ip, err)
		}
	}
}

func checkIP(ip string) (string, error) {
	cfg := tls.Config{InsecureSkipVerify: true}
	conn, err := tls.DialWithDialer(
		&net.Dialer{Timeout: 5 * time.Second},
		"tcp",
		ip+":443",
		&cfg)
	if err != nil {
		return "", err
	}
	cert := conn.ConnectionState().PeerCertificates[0]

	// XXX, refactor out DRY: genconfig.go
	domain, chain := findVerifiedChain((*cert).DNSNames, conn, &cfg)
	if domain == "" {
		return "", fmt.Errorf("Couldn't verify any cert chains for %v.", ip)
	}
	rootCA := chain[len(chain)-1]
	_, err = keyman.LoadCertificateFromX509(rootCA)
	if err != nil {
		return "", fmt.Errorf("Error loading root CA cert: %v", err)
	}
	return ip + " " + domain, nil
	/*
		ca := &castat{
			CommonName: rootCA.Subject.CommonName,
			Cert:       strings.Replace(string(rootCert.PEMEncoded()), "\n", "\\n", -1),
		}
		masq := &masquerade{
			Domain:    domain,
			IpAddress: ip,
			RootCA:    ca,
		}
		if verifyMasquerade(masq) {
			return domain, nil
		} else {
			return "", fmt.Errorf("Failed to verify masquerade for %v (%v)", domain, ip)
		}
	*/
}

func findVerifiedChain(dnsNames []string, conn *tls.Conn, cfg *tls.Config) (string, []*x509.Certificate) {
	for _, isWildcard := range []bool{false, true} {
		for _, domain := range dnsNames {
			if strings.HasPrefix(domain, "*") == isWildcard {
				if isWildcard {
					domain = "www" + domain[1:]
				}
				verifiedChains, err := verifyServerCerts(conn, domain, cfg)
				if err == nil {
					return domain, verifiedChains[0]
				}
			}
		}
	}
	return "", nil
}

func enumerateRange(cidr string, ch chan<- string, wg *sync.WaitGroup) {
	defer wg.Done()
	cidrIP, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		log.Fatal(err)
	}
	for ip := cidrIP.Mask(ipnet.Mask); ipnet.Contains(ip); inc(ip) {
		if ip.IsGlobalUnicast() {
			ch <- ip.String()
		}
	}
}

func inc(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

// XXX: copy&paste from tlsdialer.go
func verifyServerCerts(conn *tls.Conn, serverName string, config *tls.Config) ([][]*x509.Certificate, error) {
	certs := conn.ConnectionState().PeerCertificates

	opts := x509.VerifyOptions{
		Roots:         config.RootCAs,
		CurrentTime:   time.Now(),
		DNSName:       serverName,
		Intermediates: x509.NewCertPool(),
	}

	for i, cert := range certs {
		if i == 0 {
			continue
		}
		opts.Intermediates.AddCert(cert)
	}
	return certs[0].Verify(opts)
}
