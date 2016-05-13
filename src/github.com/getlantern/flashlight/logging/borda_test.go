package logging

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var (
	ts *httptest.Server
)

func init() {
	ts = newMockServer()

	testEnv := os.Getenv("TEST_ENV")
	if testEnv == "INTEGRATION" {
		log.Debugf("Performing integration test -> using external networks and services")
		bordaURL = ts.URL
	}
}

func TestBordaClient(t *testing.T) {
	bc := NewBordaReporter(
		&BordaReporterOptions{
			MaxChunkSize: 5,
		})

	assert.NotNil(t, bc)

	m := &Measurement{
		Name: "client_measurement",
		Ts:   time.Now(),
		Fields: map[string]interface{}{
			"requestid":             "18af517b-004f-486c-9978-6cf60be7f1e9",
			"ipv6":                  "2001:0db8:0a0b:12f0:0000:0000:0000:0001",
			"host":                  "myhost.mydomain.com",
			"total_cpus":            "2",
			"cpu_idle":              10.1,
			"cpu_system":            53.3,
			"cpu_user":              36.6,
			"num_errors":            67,
			"connected_to_internet": true,
		},
	}

	for i := 0; i < 4; i++ {
		sent, err := bc.AddMeasurement(m)
		assert.Nil(t, err, "Shouldn't return an error")
		assert.False(t, sent, "Shouldn't had sent the measurements yet")
	}

	sent, err := bc.AddMeasurement(m)
	assert.Nil(t, err, "Shouldn't return an error")
	assert.True(t, sent, "Should had sent the measurements")
}

func newMockServer() *httptest.Server {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(201)
	}))

	return ts
}

// Keep the last one
func TestFinalize(t *testing.T) {
	ts.Close()
}
