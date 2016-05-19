package logging

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"testing"
	"time"

	"github.com/getlantern/errors"
	"github.com/getlantern/eventual"
	"github.com/stretchr/testify/assert"
)

func TestBordaClient(t *testing.T) {
	submitted := eventual.NewValue()
	ts := newMockServer(submitted)
	defer ts.Close()
	bordaURL = ts.URL

	bc := NewBordaReporter(
		&BordaReporterOptions{
			ReportInterval: 100 * time.Millisecond,
			MaxBufferSize:  5,
		})
	bc.c.Transport = nil

	assert.NotNil(t, bc)

	err := errors.New("My Error").Op("My Op")
	ctx := map[string]interface{}{
		"ca": 1,
		"cb": true,
	}

	for i := 0; i < 20; i++ {
		bc.Report(err, "", ctx)
		_, sent := submitted.Get(0)
		assert.False(t, sent, "Shouldn't have sent the measurements yet")
	}

	time.Sleep(bc.options.ReportInterval * 2)
	_, sent := submitted.Get(0)
	assert.True(t, sent, "Should have sent the measurements")
}

func newMockServer(submitted eventual.Value) *httptest.Server {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if log.IsTraceEnabled() {
			httputil.DumpRequest(r, true)
			dump, err := httputil.DumpRequest(r, true)
			if err != nil {
				log.Errorf("Error reading request: %v", err)
			} else {
				log.Tracef("Mock server received request: %v", string(dump))
			}
		}

		decoder := json.NewDecoder(r.Body)
		var ms []*Measurement
		err := decoder.Decode(&ms)
		if err != nil {
			w.WriteHeader(500)
			io.WriteString(w, fmt.Sprintf("Error decoding JSON request: %v", err))
		} else {
			w.WriteHeader(201)
			submitted.Set(true)
		}
	}))

	return ts
}
