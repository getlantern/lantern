package main

import (
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/keyman"
	"github.com/getlantern/tlsdialer"
)

var (
	log        = golog.LoggerFor("cfscanner")
	help       = flag.Bool("help", false, "Get usage help")
	numWorkers = flag.Int("workers", 1, "Number of concurrent workers")
	out        = flag.String("o", "masquerades.txt", "Output file")
)

func webSlurp(url string) (string, error) {
	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("Error fetching IP list: %v", err)
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("Error trying to read response: %v", err)
	}
	return string(body), nil
}

type masquerade struct {
	Domain    string
	IpAddress string
	RootCA    *castat
}

type castat struct {
	CommonName string
	Cert       string
	freq       float64
}

// DirectDomainTransport is a wrapper struct enabling us to modify the protocol of outgoing
// requests to make them all HTTP instead of potentially HTTPS, which breaks our particular
// implemenation of direct domain fronting.
type DirectDomainTransport struct {
	http.Transport
}

func main() {
	main_()
}

func main_() {
	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(1)
	}

	s, err := webSlurp("https://www.cloudflare.com/ips-v4")
	if err != nil {
		log.Fatal(err)
	}
	ipch := make(chan string)
	ipwg := sync.WaitGroup{}
	lines := strings.Split(s, "\n")
	ipwg.Add(len(lines))
	for _, line := range lines {
		go enumerateRange(line, ipch, &ipwg)
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
	for domain := range resch {
		if domain == "" {
			fmt.Println("Done!")
			break
		}
		fmt.Printf("*** Successfully verified %v\n", domain)
		_, err = f.WriteString(domain + "\n")
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
		&net.Dialer{Timeout: 10 * time.Second},
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
	rootCert, err := keyman.LoadCertificateFromX509(rootCA)
	if err != nil {
		return "", fmt.Errorf("Error loading root CA cert: %v", err)
	}
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
}

func findVerifiedChain(dnsNames []string, conn *tls.Conn, cfg *tls.Config) (string, []*x509.Certificate) {
	// Hackery: try the following combinations in order of preference:
	//    Non-cloudflare, non-wildcard
	//    Non-cloudflare, wildcard
	//    Cloudflare, non-wildcard
	//    Cloudflare, wildcard
	for i := 0; i < 4; i++ {
		isWildcard := (i & 1) == 1
		isCf := (i & 2) == 1
		for _, domain := range dnsNames {
			if strings.HasPrefix(domain, "*") == isWildcard && strings.HasSuffix(domain, ".cloudflare.com") == isCf {
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
	ip, ipnet, err := net.ParseCIDR(cidr)
	if err != nil {
		log.Fatal(err)
	}
	for ip := ip.Mask(ipnet.Mask); ipnet.Contains(ip); inc(ip) {
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

//XXX: DRY: copied & pasted from genconfigWithVerify.go
func verifyMasquerade(masq *masquerade) bool {
	httpClient := NewDirectDomainFronter(masq)
	country, ip, err := lookupIp(httpClient)
	if err != nil {
		log.Errorf("Could not lookup IP: %v", err)
		return false
	}
	log.Debugf("Got country %v and ip %v", country, ip)

	return len(country) > 1
}

//XXX: DRY: copied & pasted from genconfigWithVerify.go
func lookupIp(httpClient *http.Client) (string, string, error) {
	httpClient.Timeout = 60 * time.Second

	var err error
	var req *http.Request
	var resp *http.Response

	// Note this will typically be an HTTP client that uses direct domain fronting to
	// hit our server pool in the Netherlands.
	if req, err = http.NewRequest("HEAD", "http://nl.fallbacks.getiantem.org", nil); err != nil {
		return "", "", fmt.Errorf("Could not create request: %q", err)
	}

	if resp, err = httpClient.Do(req); err != nil {
		return "", "", fmt.Errorf("Could not get response from server: %q", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close reponse body: %v", err)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		if full, err := httputil.DumpResponse(resp, true); err != nil {
			log.Errorf("Could not read full response %v", err)
		} else {
			log.Errorf("Unexpected response to geo IP lookup: %v", string(full))
		}
		return "", "", fmt.Errorf("Unexpected response status %d", resp.StatusCode)
	}

	ip := resp.Header.Get("Lantern-Ip")
	country := resp.Header.Get("Lantern-Country")

	log.Debugf("Got IP and country: %v, %v", ip, country)
	return country, ip, nil
}

// Creates a new http.Client that does direct domain fronting.
func NewDirectDomainFronter(masq *masquerade) *http.Client {
	log.Debugf("Creating new direct domain fronter.")
	return &http.Client{
		Transport: &DirectDomainTransport{
			Transport: http.Transport{
				Dial: func(network, addr string) (net.Conn, error) {
					log.Debugf("Dialing %s with direct domain fronter", addr)
					return dialServerWith(masq)
				},
				TLSHandshakeTimeout: 40 * time.Second,
				DisableKeepAlives:   true,
			},
		},
	}
}

func dialServerWith(masq *masquerade) (net.Conn, error) {
	dialTimeout := 30 * time.Second

	// Note - we need to suppress the sending of the ServerName in the client
	// handshake to make host-spoofing work with Fastly.  If the client Hello
	// includes a server name, Fastly checks to make sure that this matches the
	// Host header in the HTTP request and if they don't match, it returns
	// a 400 Bad Request error.
	sendServerNameExtension := false

	cwt, err := tlsdialer.DialForTimings(
		&net.Dialer{
			Timeout: dialTimeout,
		},
		"tcp",
		addressForServer(masq),
		sendServerNameExtension,
		tlsConfig(masq))

	if err != nil && masq != nil {
		err = fmt.Errorf("Unable to dial masquerade %s: %s", masq.Domain, err)
	}
	return cwt.Conn, err
}

// Get the address to dial for reaching the server
//func addressForServer(masq *masquerade) string {
//	return fmt.Sprintf("%s:%d", masq.IpAddress, 443)
//}

func addressForServer(masq *masquerade) string {
	return fmt.Sprintf("%s:%d", serverHost(masq), 443)
}

func serverHost(masq *masquerade) string {
	if masq.IpAddress != "" {
		return masq.IpAddress
	}
	return masq.Domain
}

// tlsConfig builds a tls.Config for dialing the upstream host. Constructed
// tls.Configs are cached on a per-masquerade basis to enable client session
// caching and reduce the amount of PEM certificate parsing.
func tlsConfig(masq *masquerade) *tls.Config {
	/*
			caCert, err := keyman.LoadCertificateFromPEMBytes([]byte(masq.RootCA.Cert))
		if err != nil {
			return nil
		}
	*/
	serverName := masq.Domain
	tlsConfig := &tls.Config{
		//ClientSessionCache: tls.NewLRUClientSessionCache(1000),
		InsecureSkipVerify: true,
		ServerName:         serverName,
		//		RootCAs:            caCert.PoolContainingCert(),
	}

	return tlsConfig
}
