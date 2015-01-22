package cf

import (
	"os"
	"testing"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

func TestAll(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}

	u, err := New("getiantem.org", os.Getenv("CF_USER"), os.Getenv("CF_API_KEY"))
	assert.NoError(t, err, "Should be able to create util")
	recs, err := u.GetAllRecords()
	if assert.NoError(t, err, "Should be able to get all records") {
		for _, r := range recs {
			log.Tracef("%v : %v", r.Domain, r.Value)
		}
		assert.True(t, len(recs) > 0, "There should be some records")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func TestFallbacks(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}

	u, err := New("getiantem.org", os.Getenv("CF_USER"), os.Getenv("CF_API_KEY"))
	assert.NoError(t, err, "Should be able to create util")
	recs, err := u.GetRotationRecords("fallbacks")
	if assert.NoError(t, err, "Should be able to get fallbacks rotation") {
		for _, r := range recs {
			log.Tracef("%v : %v", r.Domain, r.Value)
		}
		assert.True(t, len(recs) > 0, "There should be fallback records")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}
