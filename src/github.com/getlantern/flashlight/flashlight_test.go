package main

import (
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"testing"
	"time"

	"code.google.com/p/go-uuid/uuid"
	"github.com/getlantern/fronted"
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
/*
func TestCloudFlare(t *testing.T) {
	// Set up a mock HTTP server
	mockServer := &MockServer{}
	err := mockServer.init()
	if err != nil {
		t.Fatalf("Unable to init mock HTTP(S) server: %s", err)
	}
	defer func() {
		if err := mockServer.deleteCerts(); err != nil {
			t.Fatalf("Error deleting certificates: %v", err)
		}
	}()

	mockServer.run(t)
	waitForServer(HTTP_ADDR, 5*time.Second, t)
	waitForServer(HTTPS_ADDR, 5*time.Second, t)

	// Set up a mock CloudFlare
	cf := &MockCloudFlare{}
	err = cf.init()
	if err != nil {
		t.Fatalf("Unable to init mock CloudFlare: %s", err)
	}
	defer func() {
		if err := cf.deleteCerts(); err != nil {
			t.Fatalf("Error deleting certificates: %v", err)
		}
	}()

	go func() {
		err := cf.run(t)
		if err != nil {
			t.Fatalf("Unable to run mock CloudFlare: %s", err)
		}
	}()
	waitForServer(CF_ADDR, 5*time.Second, t)

	// Set up common certContext for proxies
	certContext := &fronted.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}
	defer func() {
		if err := os.Remove(certContext.PKFile); err != nil {
			t.Fatalf("Error removing PKFile: %v", err)
		}
	}()
	defer func() {
		if err := os.Remove(certContext.ServerCertFile); err != nil {
			t.Fatalf("Error removing Server Certificate: %v", err)
		}
	}()

	// Run server proxy
	srv := &server.Server{
		Addr:                       SERVER_ADDR,
		ReadTimeout:                0, // don't timeout
		WriteTimeout:               0,
		CertContext:                certContext,
		AllowNonGlobalDestinations: true,
	}
	srv.Configure(&server.ServerConfig{})
	go func() {
		err := srv.ListenAndServe(func(update func(*server.ServerConfig) error) {
			err := config.Update(func(cfg *config.Config) error {
				return update(cfg.Server)
			})
			if err != nil {
				log.Errorf("Error while trying to update: %v", err)
			}
		})
		if err != nil {
			t.Fatalf("Unable to run server: %s", err)
		}
	}()
	waitForServer(SERVER_ADDR, 5*time.Second, t)

	// Give servers time to finish startup
	time.Sleep(250 * time.Millisecond)

	clt := &client.Client{
		Addr:         CLIENT_ADDR,
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
	}

	certs := []string{
		"-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n",
		string(cf.certContext.ServerCert.PEMEncoded()),
	}

	pool, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Fatalf("Could not create pool %v", err)
	}
	clt.Configure(&client.ClientConfig{
		MasqueradeSets: map[string][]*fronted.Masquerade{
			"cloudflare": []*fronted.Masquerade{
				&fronted.Masquerade{
					Domain: HOST,
				},
			},
		},
		FrontedServers: []*client.FrontedServerInfo{
			&client.FrontedServerInfo{Host: HOST, Port: CF_PORT, Weight: 100, MasqueradeSet: "cloudflare"},
		},
	}, pool)
	go func() {
		err := clt.ListenAndServe(func() {})
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
*/

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
		defer func() {
			if err := resp.Body.Close(); err != nil {
				t.Fatalf("Error closing response body: %s", err)
			}
		}()
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
	certContext *fronted.CertContext
	requests    chan *http.Request // publishes received requests
}

func (srv *MockServer) init() error {
	srv.certContext = &fronted.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}

	err := srv.certContext.InitServerCert(HOST)
	if err != nil {
		log.Errorf("Unable to initialize mock server cert: %s", err)
	}

	srv.requests = make(chan *http.Request, 100)
	return nil
}

func (server *MockServer) deleteCerts() (err error) {
	if err = os.Remove(server.certContext.PKFile); err != nil {
		return err
	}
	err = os.Remove(server.certContext.ServerCertFile)
	return
}

func (server *MockServer) run(t *testing.T) {
	httpServer := &http.Server{
		Addr:    HTTP_ADDR,
		Handler: http.HandlerFunc(server.handle(t)),
	}

	httpsServer := &http.Server{
		Addr:    HTTPS_ADDR,
		Handler: http.HandlerFunc(server.handle(t)),
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

func (server *MockServer) handle(t *testing.T) func(http.ResponseWriter, *http.Request) {
	return func(resp http.ResponseWriter, req *http.Request) {
		if _, err := resp.Write([]byte(EXPECTED_BODY)); err != nil {
			t.Errorf("Unable to write response body: %v", err)
		}
		server.requests <- req
	}
}

// MockCloudFlare is a ReverseProxy that pretends to be CloudFlare
type MockCloudFlare struct {
	certContext *fronted.CertContext
}

func (cf *MockCloudFlare) init() error {
	cf.certContext = &fronted.CertContext{
		PKFile:         randomTempPath(),
		ServerCertFile: randomTempPath(),
	}

	err := cf.certContext.InitServerCert(HOST)
	if err != nil {
		log.Errorf("Unable to initialize mock CloudFlare server cert: %s", err)
	}
	return nil
}

func (cf *MockCloudFlare) deleteCerts() (err error) {
	if err = os.Remove(cf.certContext.PKFile); err != nil {
		return err
	}
	err = os.Remove(cf.certContext.ServerCertFile)
	return
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
			if err := c.Close(); err != nil {
				t.Errorf("Error closing connection: %v", err)
			}
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
}
