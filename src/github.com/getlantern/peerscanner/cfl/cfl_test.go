package cfl

import (
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

func TestAll(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}

	u := New("getiantem.org", os.Getenv("CFL_USER"), os.Getenv("CFL_API_KEY"))
	u.Client.Http.Transport = &http.Transport{
		DisableKeepAlives: true,
	}
	recs, err := u.GetAllRecords()
	if assert.NoError(t, err, "Should be able to get all records") {
		for _, r := range recs {
			log.Tracef("%v : %v", r.Domain, r.Value)
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

	u := New("getiantem.org", os.Getenv("CFL_USER"), os.Getenv("CFL_API_KEY"))
	u.Client.Http.Transport = &http.Transport{
		DisableKeepAlives: true,
	}
	rec, err := u.Register("cfl-test-entry", "127.0.0.1", true)
	if err != nil && strings.Contains(err.Error(), "The record already exists.") {
		// Duplicates are okay
		err = nil
	}
	if assert.NoError(t, err, "Should be able to register") {
		err := u.DestroyRecord(rec)
		assert.NoError(t, err, "Should be able to destroy record")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}
