package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"testing"
	"time"

	"code.google.com/p/go-uuid/uuid"
	"github.com/getlantern/enproxy"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/server"
)

const (
	HOST        = "127.0.0.1"
	CF_PORT     = 19871
	CF_ADDR     = HOST + ":19871"
	CLIENT_PORT = 19872
	CLIENT_ADDR = HOST + ":19872"
	SERVER_PORT = 19873
	SERVER_ADDR = HOST + ":19873"
	HTTP_ADDR   = HOST + ":19874"
	HTTPS_ADDR  = HOST + ":19875"

	EXPECTED_BODY    = "This is some stuff that goes in the body\n"
	FORWARDED_FOR_IP = "192.168.1.1"
)

// TestCloudFlare tests to make sure that a client and server can communicate
// with each other to proxy traffic for an HTTP client using the CloudFlare
// protocol.  This does not test actually running through CloudFlare and just
// uses a local HTTP server to serve the test content.
func TestCloudFlare(t *testing.T) {
	// Set up a mock HTTP server
	mockServer := &MockServer{}
	err := mockServer.init()
	if err != nil {
		t.Fatalf("Unable to init mock HTTP(S) server: %s", err)
	}
	defer mockServer.deleteCerts()

	mockServer.run(t)
	waitForServer(HTTP_ADDR, 2*time.Second, t)
	waitForServer(HTTPS_ADDR, 2*time.Second, t)

	// Set up a mock CloudFlare
	cf := &MockCloudFlare{}
	err = cf.init()
	if err != nil {
		t.Fatalf("Unable to init mock CloudFlare: %s", err)
	}
	defer cf.deleteCerts()

	go func() {
		err := cf.run(t)
		if err != nil {
			t.Fatalf("Unable to run mock CloudFlare: %s", err)
		}
	}()
	waitForServer(CF_ADDR, 2*time.Second, t)

	// Set up common certContext for proxies
	certContext := &server.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}
	defer os.Remove(certContext.PKFile)
	defer os.Remove(certContext.ServerCertFile)

	// Run server proxy
	server := &server.Server{
		Addr:                       SERVER_ADDR,
		ReadTimeout:                0, // don't timeout
		WriteTimeout:               0,
		CertContext:                certContext,
		AllowNonGlobalDestinations: true,
	}
	go func() {
		err := server.ListenAndServe()
		if err != nil {
			t.Fatalf("Unable to run server: %s", err)
		}
	}()
	waitForServer(SERVER_ADDR, 2*time.Second, t)

	clt := &client.Client{
		Addr:         CLIENT_ADDR,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	clt.Configure(&client.ClientConfig{
		MasqueradeSets: map[string][]*client.Masquerade{
			"cloudflare": []*client.Masquerade{
				&client.Masquerade{
					Domain: "filmesonlinegratis.net",
					RootCA: "-----BEGIN CERTIFICATE-----\nMIIEYDCCA0igAwIBAgILBAAAAAABL07hRQwwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw0xMTA0MTMxMDAw\nMDBaFw0yMjA0MTMxMDAwMDBaMF0xCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMTMwMQYDVQQDEypHbG9iYWxTaWduIE9yZ2FuaXphdGlvbiBW\nYWxpZGF0aW9uIENBIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB\nAQDdNR3yIFQmGtDvpW+Bdllw3Of01AMkHyQOnSKf1Ccyeit87ovjYWI4F6+0S3qf\nZyEcLZVUunm6tsTyDSF0F2d04rFkCJlgePtnwkv3J41vNnbPMYzl8QbX3FcOW6zu\nzi2rqqlwLwKGyLHQCAeV6irs0Z7kNlw7pja1Q4ur944+ABv/hVlrYgGNguhKujiz\n4MP0bRmn6gXdhGfCZsckAnNate6kGdn8AM62pI3ffr1fsjqdhDFPyGMM5NgNUqN+\nARvUZ6UYKOsBp4I82Y4d5UcNuotZFKMfH0vq4idGhs6dOcRmQafiFSNrVkfB7cVT\n5NSAH2v6gEaYsgmmD5W+ZoiTAgMBAAGjggElMIIBITAOBgNVHQ8BAf8EBAMCAQYw\nEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUXUayjcRLdBy77fVztjq3OI91\nnn4wRwYDVR0gBEAwPjA8BgRVHSAAMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3\nLmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMDMGA1UdHwQsMCowKKAmoCSGImh0\ndHA6Ly9jcmwuZ2xvYmFsc2lnbi5uZXQvcm9vdC5jcmwwPQYIKwYBBQUHAQEEMTAv\nMC0GCCsGAQUFBzABhiFodHRwOi8vb2NzcC5nbG9iYWxzaWduLmNvbS9yb290cjEw\nHwYDVR0jBBgwFoAUYHtmGkUNl8qJUC99BM00qP/8/UswDQYJKoZIhvcNAQEFBQAD\nggEBABvgiADHBREc/6stSEJSzSBo53xBjcEnxSxZZ6CaNduzUKcbYumlO/q2IQen\nfPMOK25+Lk2TnLryhj5jiBDYW2FQEtuHrhm70t8ylgCoXtwtI7yw07VKoI5lkS/Z\n9oL2dLLffCbvGSuXL+Ch7rkXIkg/pfcNYNUNUUflWP63n41edTzGQfDPgVRJEcYX\npOBWYdw9P91nbHZF2krqrhqkYE/Ho9aqp9nNgSvBZnWygI/1h01fwlr1kMbawb30\nhag8IyrhFHvBN91i0ZJsumB9iOQct+R2UTjEqUdOqCsukNK1OFHrwZyKarXMsh3o\nwFZUTKiL8IkyhtyTMr5NGvo1dbU=\n-----END CERTIFICATE-----\n",
				},
			},
		},
		Servers: []*client.ServerInfo{
			&client.ServerInfo{Weight: 100, Port: 443, MasqueradeSet: "cloudflare"},
		},
	}, []*enproxy.Config{
		&enproxy.Config{
			DialProxy: func(addr string) (net.Conn, error) {
				return tls.Dial("tcp", CF_ADDR, &tls.Config{
					RootCAs: cf.certContext.ServerCert.PoolContainingCert(),
				})
			},
			NewRequest: func(host string, method string, body io.Reader) (req *http.Request, err error) {
				if host == "" {
					host = SERVER_ADDR
				}
				return http.NewRequest(method, "http://"+host, body)
			},
		},
	})
	go func() {
		err := clt.ListenAndServe()
		if err != nil {
			t.Fatalf("Unable to run client: %s", err)
		}
	}()
	waitForServer(CLIENT_ADDR, 2*time.Second, t)

	// Test various scenarios
	certPool := mockServer.certContext.ServerCert.PoolContainingCert()
	testRequest("Plain Text Request", t, mockServer.requests, false, certPool, 200, nil)
	testRequest("HTTPS Request", t, mockServer.requests, true, certPool, 200, nil)
	testRequest("HTTPS Request without server Cert", t, mockServer.requests, true, nil, 200, fmt.Errorf("Get https://"+HTTPS_ADDR+": x509: certificate signed by unknown authority"))
}

// testRequest tests an individual request, either HTTP or HTTPS, making sure
// that the response status and body match the expected values.  If the request
// was successful, it also tests to make sure that the outbound request didn't
// leak any Lantern or CloudFlare headers.
func testRequest(testCase string, t *testing.T, requests chan *http.Request, https bool, certPool *x509.CertPool, expectedStatus int, expectedErr error) {
	httpClient := &http.Client{Transport: &http.Transport{
		Proxy: func(req *http.Request) (*url.URL, error) {
			return url.Parse("http://" + CLIENT_ADDR)
		},

		TLSClientConfig: &tls.Config{
			RootCAs: certPool,
		},
	}}

	var destURL string
	if https {
		destURL = "https://" + HTTPS_ADDR
	} else {
		destURL = "http://" + HTTP_ADDR
	}
	req, err := http.NewRequest("GET", destURL, nil)
	if err != nil {
		t.Fatalf("Unable to construct request: %s", err)
	}
	resp, err := httpClient.Do(req)

	requestSuccessful := err == nil
	gotCorrectError := expectedErr == nil && err == nil ||
		expectedErr != nil && err != nil && err.Error() == expectedErr.Error()
	if !gotCorrectError {
		t.Errorf("%s: Wrong error.\nExpected: %s\nGot     : %s", testCase, expectedErr, err)
	} else if requestSuccessful {
		defer resp.Body.Close()
		if resp.StatusCode != expectedStatus {
			t.Errorf("%s: Wrong response status. Expected %d, got %d", testCase, expectedStatus, resp.StatusCode)
		} else {
			// Check body
			body, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				t.Errorf("%s: Unable to read response body: %s", testCase, err)
			} else if string(body) != EXPECTED_BODY {
				t.Errorf("%s: Body didn't contain expected text.\nExpected: %s\nGot     : '%s'", testCase, EXPECTED_BODY, string(body))
			}
		}
	}
}

// MockServer is an HTTP+S server that serves up simple responses
type MockServer struct {
	certContext *server.CertContext
	requests    chan *http.Request // publishes received requests
}

func (srv *MockServer) init() error {
	srv.certContext = &server.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}

	err := srv.certContext.InitServerCert(HOST)
	if err != nil {
		fmt.Errorf("Unable to initialize mock server cert: %s", err)
	}

	srv.requests = make(chan *http.Request, 100)
	return nil
}

func (server *MockServer) deleteCerts() {
	os.Remove(server.certContext.PKFile)
	os.Remove(server.certContext.ServerCertFile)
}

func (server *MockServer) run(t *testing.T) {
	httpServer := &http.Server{
		Addr:    HTTP_ADDR,
		Handler: http.HandlerFunc(server.handle),
	}

	httpsServer := &http.Server{
		Addr:    HTTPS_ADDR,
		Handler: http.HandlerFunc(server.handle),
	}

	go func() {
		t.Logf("About to start mock HTTP at: %s", httpServer.Addr)
		err := httpServer.ListenAndServe()
		if err != nil {
			t.Errorf("Unable to start HTTP server: %s", err)
		}
	}()

	go func() {
		t.Logf("About to start mock HTTPS at: %s", httpsServer.Addr)
		err := httpsServer.ListenAndServeTLS(server.certContext.ServerCertFile, server.certContext.PKFile)
		if err != nil {
			t.Errorf("Unable to start HTTP server: %s", err)
		}
	}()
}

func (server *MockServer) handle(resp http.ResponseWriter, req *http.Request) {
	resp.Write([]byte(EXPECTED_BODY))
	server.requests <- req
}

// MockCloudFlare is a ReverseProxy that pretends to be CloudFlare
type MockCloudFlare struct {
	certContext *server.CertContext
}

func (cf *MockCloudFlare) init() error {
	cf.certContext = &server.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}

	err := cf.certContext.InitServerCert(HOST)
	if err != nil {
		fmt.Errorf("Unable to initialize mock CloudFlare server cert: %s", err)
	}
	return nil
}

func (cf *MockCloudFlare) deleteCerts() {
	os.Remove(cf.certContext.PKFile)
	os.Remove(cf.certContext.ServerCertFile)
}

func (cf *MockCloudFlare) run(t *testing.T) error {
	httpServer := &http.Server{
		Addr: CF_ADDR,
		Handler: &httputil.ReverseProxy{
			Director: func(req *http.Request) {
				req.URL.Scheme = "https"
				req.URL.Host = SERVER_ADDR
				req.Host = SERVER_ADDR
			},
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{
					// Real CloudFlare doesn't verify our cert, so mock doesn't
					// either
					InsecureSkipVerify: true,
				},
			},
		},
	}

	t.Logf("About to start mock CloudFlare at: %s", httpServer.Addr)
	return httpServer.ListenAndServeTLS(cf.certContext.ServerCertFile, cf.certContext.PKFile)
}

// randomTempPath creates a random file path in the temp folder (doesn't create
// a file)
func randomTempPath() string {
	return os.TempDir() + string(os.PathSeparator) + uuid.New()
}

// waitForServer waits for a TCP server to start at the given address, waiting
// up to the given limit and reporting an error to the given testing.T if the
// server didn't start within the time limit.
func waitForServer(addr string, limit time.Duration, t *testing.T) {
	cutoff := time.Now().Add(limit)
	for {
		if time.Now().After(cutoff) {
			t.Errorf("Server never came up at address %s", addr)
			return
		}
		c, err := net.DialTimeout("tcp", addr, limit)
		if err == nil {
			c.Close()
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
}
