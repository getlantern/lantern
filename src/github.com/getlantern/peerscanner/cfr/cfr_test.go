package cfr

import (
	"net/http"
	"os"
	//	"strings"
	"testing"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

func TestList(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	cfr := New(os.Getenv("CFR_ID"), os.Getenv("CFR_KEY"), httpClientWithDisabledKeepAlives())
	dists, err := ListDistributions(cfr)
	if assert.NoError(t, err, "Should be able to get all distributions") {
		for _, d := range dists {
			log.Tracef("%v : %v (%v)", d.InstanceId, d.Domain, d.Status)
		}
		assert.True(t, len(dists) > 0, "There should be some distributions")
	}
	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

//func TestRegister(t *testing.T) {
//	_, counter, err := fdcount.Matching("TCP")
//	if err != nil {
//		t.Fatalf("Unable to get starting fdcount: %v", err)
//	}
//
//	cfr := New("getiantem.org", os.Getenv("CFL_USER"), os.Getenv("CFL_API_KEY"))
//	cfr.Client.Http.Transport = &http.Transport{
//		DisableKeepAlives: true,
//	}
//	rec, err := cfr.Register("cfl-test-entry", "127.0.0.1")
//	if err != nil && strings.Contains(err.Error(), "The record already exists.") {
//		// Duplicates are okay
//		err = nil
//	}
//	if assert.NoError(t, err, "Should be able to register") {
//		err := cfr.DestroyRecord(rec)
//		assert.NoError(t, err, "Should be able to destroy record")
//	}
//
//	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
//}

func httpClientWithDisabledKeepAlives() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DisableKeepAlives: true,
		},
	}
}
