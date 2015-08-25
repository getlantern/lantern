package dsp

import (
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

func TestAll(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	u := getUtil()
	recs, err := u.GetAllRecords()
	if assert.NoError(t, err, "Should be able to get all records") {
		for _, r := range recs {
			log.Tracef("%v : %v", r.Name, r.Content)
		}
		assert.True(t, len(recs) > 0, "There should be some records")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func TestRegister(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	u := getUtil()
	// Test with no existing record
	name, ip := "dsp-test-entry", "127.0.0.1"
	rec, err := u.Register(name, ip)
	if assert.NoError(t, err, "Should be able to register with no record") {
		assert.NotNil(t, rec, "A new record should have been returned")
	}

	// give dnssimple enough time to complete the operation
	time.Sleep(100 * time.Millisecond)
	if rec != nil {
		err := u.DestroyRecord(rec)
		assert.NoError(t, err, "Should be able to destroy record")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func getUtil() *Util {
	dspid := os.Getenv("DSP_ID")
	dspkey := os.Getenv("DSP_KEY")
	if dspid == "" || dspkey == "" {
		log.Fatalf("You need to set DSP_ID and DSP_KEY environment variables (e.g. `source <too-few-secrets>/envvars.bash`)")
	}
	u := New("flashlightproxy.org", dspid, dspkey)
	u.Client.HttpClient.Transport = &http.Transport{
		DisableKeepAlives: true,
	}
	return u
}
