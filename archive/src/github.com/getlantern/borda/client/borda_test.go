package client

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/eventual"
	"github.com/stretchr/testify/assert"
)

func TestBordaClient(t *testing.T) {
	submitted := eventual.NewValue()
	ts := newMockServer(submitted)
	defer ts.Close()
	bordaURL = ts.URL

	bc := NewClient(
		&Options{
			BatchInterval: 100 * time.Millisecond,
		})
	assert.NotNil(t, bc)
	submit := bc.ReducingSubmitter("errors", 5, func(existingValues map[string]float64, newValues map[string]float64) {
		existingValues["error_count"] += newValues["error_count"]
	})

	numUniqueErrors := 3
	countOfEachError := 10
	for i := 0; i < numUniqueErrors*countOfEachError; i++ {
		values := map[string]float64{
			"error_count": 1,
		}
		dims := map[string]interface{}{
			"ca": (i % numUniqueErrors) + 1,
			"cb": true,
		}
		submit(values, dims)
		_, sent := submitted.Get(0)
		assert.False(t, sent, "Shouldn't have sent the measurements yet")
	}

	time.Sleep(bc.options.BatchInterval * 3)
	_ms, sent := submitted.Get(0)
	if assert.True(t, sent, "Should have sent the measurements") {
		ms := _ms.([]*Measurement)
		if assert.Len(t, ms, numUniqueErrors, "Wrong number of measurements sent") {
			for i := 0; i < numUniqueErrors; i++ {
				m := ms[i]
				assert.EqualValues(t, countOfEachError, m.Values["error_count"])
				var dims map[string]interface{}
				err2 := json.Unmarshal(m.Dimensions, &dims)
				if assert.NoError(t, err2) {
					ca := dims["ca"].(float64)
					assert.True(t, 1 <= ca)
					assert.True(t, ca <= 3)
					assert.EqualValues(t, dims["cb"], true)
				}
			}
		}
	}

	// Send another measurement and make sure that gets through too
	values := map[string]float64{
		"success_count": 1,
	}
	dims := map[string]interface{}{
		"cc": "c",
	}
	submit(values, dims)
	bc.Flush()
	_ms, _ = submitted.Get(0)
	if assert.Len(t, _ms, 1) {
		ms := _ms.([]*Measurement)
		assert.EqualValues(t, 1, ms[0].Values["success_count"])
	}
}

func newMockServer(submitted eventual.Value) *httptest.Server {
	numberOfSuccesses := int32(0)
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
			fmt.Fprintf(w, "Error decoding JSON request: %v", err)
		} else {
			if atomic.AddInt32(&numberOfSuccesses, 1) == 1 {
				w.WriteHeader(500)
				fmt.Fprintf(w, "Failing on first success: %v", err)
			}
			w.WriteHeader(201)
			submitted.Set(ms)
		}
	}))

	return ts
}
