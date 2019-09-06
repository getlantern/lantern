package flashlight

import (
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"net"
	"net/http"
	"net/url"
	"os"
	"testing"
	"time"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/fronted"

	"github.com/stretchr/testify/assert"
)

const (
	HOST       = "127.0.0.1"
	cfPort     = 19871
	cfAddr     = HOST + ":19871"
	clientPort = 19872
	clientAddr = HOST + ":19872"
	serverPort = 19873
	serverAddr = HOST + ":19873"
	httpAddr   = HOST + ":19874"
	httpsAddr  = HOST + ":19875"

	expectedBody   = "This is some stuff that goes in the body\n"
	forwardedForIP = "192.168.1.1"
)

// testRequest tests an individual request, either HTTP or HTTPS, making sure
// that the response status and body match the expected values.  If the request
// was successful, it also tests to make sure that the outbound request didn't
// leak any Lantern or CloudFlare headers.
func testRequest(testCase string, t *testing.T, requests chan *http.Request, https bool, certPool *x509.CertPool, expectedStatus int, expectedErr error) {
	dir, err := ioutil.TempDir("", "direct_test")
	if !assert.NoError(t, err, "Unable to create temp dir") {
		return
	}
	defer os.RemoveAll(dir)
	fronted.ConfigureForTest(t)

	log.Debug("Making request")
	httpClient := &http.Client{Transport: &http.Transport{
		Proxy: func(req *http.Request) (*url.URL, error) {
			return url.Parse("http://" + clientAddr)
		},

		TLSClientConfig: &tls.Config{
			RootCAs: certPool,
		},
	}}

	var destURL string
	if https {
		destURL = "https://" + httpsAddr
	} else {
		destURL = "http://" + httpAddr
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
			} else if string(body) != expectedBody {
				t.Errorf("%s: Body didn't contain expected text.\nExpected: %s\nGot     : '%s'", testCase, expectedBody, string(body))
			}
		}
	}
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
