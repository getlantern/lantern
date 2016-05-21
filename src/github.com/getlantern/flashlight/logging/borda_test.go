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
	numUniqueErrors := 3
	countOfEachError := 10
	for i := 0; i < numUniqueErrors*countOfEachError; i++ {
		ctx := map[string]interface{}{
			"ca": i % numUniqueErrors,
			"cb": true,
		}
		bc.Report(err, "", ctx)
		_, sent := submitted.Get(0)
		assert.False(t, sent, "Shouldn't have sent the measurements yet")
	}

	time.Sleep(bc.options.ReportInterval * 2)
	_ms, sent := submitted.Get(0)
	if assert.True(t, sent, "Should have sent the measurements") {
		ms := _ms.([]*Measurement)
		if assert.Len(t, ms, numUniqueErrors, "Wrong number of measurements sent") {
			for i := 0; i < numUniqueErrors; i++ {
				var fields map[string]interface{}
				err2 := json.Unmarshal(ms[i].Fields, &fields)
				if assert.NoError(t, err2) {
					assert.EqualValues(t, countOfEachError, fields["error_count"])
				}
			}
		}
	}
}

func newMockServer(submitted eventual.Value) *httptest.Server {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		httputil.DumpRequest(r, true)
		dump, err := httputil.DumpRequest(r, true)
		if err != nil {
			log.Errorf("Error reading request: %v", err)
		} else {
			log.Tracef("Mock server received request: %v", string(dump))
		}

		decoder := json.NewDecoder(r.Body)
		var ms []*Measurement
		err = decoder.Decode(&ms)
		if err != nil {
			w.WriteHeader(500)
			io.WriteString(w, fmt.Sprintf("Error decoding JSON request: %v", err))
		} else {
			w.WriteHeader(201)
			submitted.Set(ms)
		}
	}))

	return ts
}
