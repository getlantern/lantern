package fronted

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"strconv"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/keyman"
	"github.com/getlantern/proxy"
	"github.com/getlantern/testify/assert"
)

const (
	expectedGoogleResponse = "Google is built by a large team of engineers, designers, researchers, robots, and others in many different sites across the globe. It is updated continuously, and built with more tools and technologies than we can shake a stick at. If you'd like to help us out, see google.com/careers.\n"
)

func TestBadProtocol(t *testing.T) {
	d := NewDialer(Config{})
	_, err := d.Dial("udp", "127.0.0.1:25324")
	assert.Error(t, err, "Using a non-tcp protocol should have resulted in an error")
}

func TestBadEnproxyConn(t *testing.T) {
	d := NewDialer(Config{
		Host: "localhost",
		Port: 3253,
	})
	_, err := d.Dial("tcp", "www.google.com")
	assert.Error(t, err, "Dialing using a non-existent host should have failed")
}

func TestReplaceBadOnDial(t *testing.T) {
	d := NewDialer(Config{
		Host: "fallbacks.getiantem.org",
		Port: 443,
		OnDial: func(conn net.Conn, err error) (net.Conn, error) {
			return nil, fmt.Errorf("Gotcha!")
		},
	})
	_, err := d.Dial("tcp", "www.google.com")
	assert.Error(t, err, "Dialing using a bad OnDial should fail")
}

func TestHttpClientWithBadEnproxyConn(t *testing.T) {
	d := NewDialer(Config{
		Host: "localhost",
		Port: 3253,
	})
	hc := d.HttpClientUsing(nil)
	_, err := hc.Get("http://www.google.com/humans.txt")
	assert.Error(t, err, "HttpClient using a non-existent host should have failed")
}

func TestBadPKFile(t *testing.T) {
	server := &Server{
		Addr: "localhost:0",
		CertContext: &CertContext{
			PKFile:         "",
			ServerCertFile: "testcert.pem",
		},
	}
	_, err := server.Listen()
	assert.Error(t, err, "Listen should have failed")
}

func TestBadCertificateFile(t *testing.T) {
	server := &Server{
		Addr: "localhost:0",
		CertContext: &CertContext{
			PKFile:         "testpk.pem",
			ServerCertFile: "",
		},
	}
	_, err := server.Listen()
	assert.Error(t, err, "Listen should have failed")
}

func TestNonGlobalAddress(t *testing.T) {
	doTestNonGlobalAddress(t, "")
}

func TestNonGlobalAddressNoPort(t *testing.T) {
	doTestNonGlobalAddress(t, "localhost")
}

func TestNonGlobalAddressNoHost(t *testing.T) {
	doTestNonGlobalAddress(t, ":0")
}

func doTestNonGlobalAddress(t *testing.T, overrideAddr string) {
	l := startServer(t, false, nil)
	d := dialerFor(t, l, 0)
	defer d.Close()

	gotConn := false
	var gotConnMutex sync.Mutex
	tl, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}
	go func() {
		tl.Accept()
		gotConnMutex.Lock()
		gotConn = true
		gotConnMutex.Unlock()
	}()

	addr := tl.Addr().String()
	if overrideAddr != "" {
		addr = overrideAddr
	}
	conn, err := d.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to dial %v: %v", addr, err)
	}

	data := []byte("Some Meaningless Data")
	conn.Write(data)
	// Give enproxy time to flush
	time.Sleep(500 * time.Millisecond)
	_, err = conn.Write(data)
	assert.Error(t, err, "Sending data after previous attempt to write to local address should have failed")
	assert.False(t, gotConn, "Sending data to local address should never have resulted in connection")
}

func TestAllowed(t *testing.T) {
	gotConn := false
	var gotConnMutex sync.Mutex
	tl, err := net.Listen("tcp", "localhost:0")
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}
	go func() {
		tl.Accept()
		gotConnMutex.Lock()
		gotConn = true
		gotConnMutex.Unlock()
	}()

	_, portString, err := net.SplitHostPort(tl.Addr().String())
	if err != nil {
		t.Fatalf("Unable to get port for test server: %v", err)
	}

	port, err := strconv.Atoi(portString)
	if err != nil {
		t.Fatalf("Unable to convert port %v to integer: %v", portString, err)
	}
	// Only allow some port other than the actual port
	l := startServer(t, true, []int{port + 1})
	d := dialerFor(t, l, 0)
	defer d.Close()

	addr := tl.Addr().String()
	conn, err := d.Dial("tcp", addr)
	defer conn.Close()

	data := []byte("Some Meaningless Data")
	conn.Write(data)
	// Give enproxy time to flush
	time.Sleep(500 * time.Millisecond)
	_, err = conn.Write(data)
	assert.Error(t, err, "Sending data after previous attempt to write to disallowed port should have failed")
	assert.False(t, gotConn, "Sending data to disallowed port should never have resulted in connection")
}

func TestRoundTripPooled(t *testing.T) {
	l := startServer(t, true, nil)
	d := dialerFor(t, l, 20)
	defer d.Close()

	proxy.Test(t, d)
}

func TestRoundTripUnpooled(t *testing.T) {
	l := startServer(t, true, nil)
	d := dialerFor(t, l, 0)
	defer d.Close()

	proxy.Test(t, d)
}

// TestIntegration tests against existing domain-fronted servers running on
// CloudFlare.
func TestIntegration(t *testing.T) {
	dialedDomain := ""
	dialedAddr := ""
	actualResolutionTime := time.Duration(0)
	actualConnectTime := time.Duration(0)
	actualHandshakeTime := time.Duration(0)
	var statsMutex sync.Mutex

	statsFunc := func(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration) {
		if success {
			statsMutex.Lock()
			defer statsMutex.Unlock()
			dialedDomain = domain
			dialedAddr = addr
			actualResolutionTime = resolutionTime
			actualConnectTime = connectTime
			actualHandshakeTime = handshakeTime
		}
	}

	d := integrationDialer(t, statsFunc)
	defer d.Close()

	hc := &http.Client{
		Transport: &http.Transport{
			Dial: d.Dial,
		},
	}

	resp, err := hc.Get("https://www.google.com/humans.txt")
	if err != nil {
		t.Fatalf("Unable to fetch from Google: %s", err)
	}
	defer resp.Body.Close()
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("Unable to read response from Google: %s", err)
	}
	assert.Equal(t, expectedGoogleResponse, string(b), "Didn't get expected response from Google")

	statsMutex.Lock()
	defer statsMutex.Unlock()
	assert.True(t, dialedDomain == "100partnerprogramme.de" || dialedDomain == "10minutemail.com", "Dialed domain didn't match one of the masquerade domains", dialedDomain)
	assert.NotEqual(t, "", dialedAddr, "Should have received an addr")
	assert.NotEqual(t, time.Duration(0), actualResolutionTime, "Should have received a resolutionTime")
	assert.NotEqual(t, time.Duration(0), actualConnectTime, "Should have received a connectTime")
	assert.NotEqual(t, time.Duration(0), actualHandshakeTime, "Should have received a handshakeTime")
}

func TestIntegrationDirect(t *testing.T) {
	d := integrationDialer(t, nil)
	defer d.Close()

	client := d.NewDirectDomainFronter()
	resp, err := client.Get("http://geo.getiantem.org/lookup")
	if assert.NoError(t, err, "Should be able to call geo.getiantem.org") {
		defer resp.Body.Close()
		if assert.Equal(t, 200, resp.StatusCode, "Response should be successful") {
			reflectedIp := resp.Header.Get("X-Reflected-Ip")
			assert.NotEmpty(t, reflectedIp, "Response from geo.getiantem.org should contains a reflected ip")
		}
	}
}

func integrationDialer(t *testing.T, statsFunc func(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration)) Dialer {
	rootCAs, err := keyman.PoolContainingCerts("-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n")
	if err != nil {
		t.Fatalf("Unable to set up cert pool")
	}

	maxMasquerades := 10
	masquerades := make([]*Masquerade, maxMasquerades*2)
	for i := 0; i < len(masquerades); i++ {
		switch i % 3 {
		case 0:
			// Good masquerade without IP
			masquerades[i] = &Masquerade{
				Domain: "100partnerprogramme.de",
			}
		case 1:
			// Good masquerade with IP
			masquerades[i] = &Masquerade{
				Domain:    "10minutemail.com",
				IpAddress: "162.159.250.16",
			}
		case 2:
			// Bad masquerade
			masquerades[i] = &Masquerade{
				Domain: "103243423minutemail.com",
			}
		}
	}

	return NewDialer(Config{
		Host:           "fallbacks.getiantem.org",
		Port:           443,
		Masquerades:    masquerades,
		MaxMasquerades: maxMasquerades,
		RootCAs:        rootCAs,
		OnDialStats:    statsFunc,
	})
}

func startServer(t *testing.T, allowNonGlobal bool, allowedPorts []int) net.Listener {
	server := &Server{
		Addr: "localhost:0",
		AllowNonGlobalDestinations: allowNonGlobal,
		CertContext: &CertContext{
			PKFile:         "testpk.pem",
			ServerCertFile: "testcert.pem",
		},
	}
	if allowedPorts != nil {
		server.Allow = func(req *http.Request, destAddr string) error {
			_, portString, err := net.SplitHostPort(destAddr)
			if err != nil {
				t.Fatalf("Unable to split host and port: %v", err)
			}
			port, err := strconv.Atoi(portString)
			if err != nil {
				t.Fatalf("Unable to parse port: %s", err)
			}
			portAllowed := false
			for _, allowed := range allowedPorts {
				if allowed == port {
					portAllowed = true
					break
				}
			}
			if !portAllowed {
				return fmt.Errorf("Port %v not allowed", portAllowed)
			}
			return nil
		}
	}
	l, err := server.Listen()
	if err != nil {
		t.Fatalf("Unable to listen: %s", err)
	}
	go func() {
		err = server.Serve(l)
		if err != nil {
			t.Fatalf("Unable to serve: %s", err)
		}
	}()
	return l
}

func dialerFor(t *testing.T, l net.Listener, poolSize int) Dialer {
	host, portString, err := net.SplitHostPort(l.Addr().String())
	if err != nil {
		t.Fatalf("Unable to split host and port: %v", err)
	}
	port, err := strconv.Atoi(portString)
	if err != nil {
		t.Fatalf("Unable to parse port: %s", err)
	}

	return NewDialer(Config{
		Host:               host,
		Port:               port,
		PoolSize:           poolSize,
		InsecureSkipVerify: true,
	})
}
