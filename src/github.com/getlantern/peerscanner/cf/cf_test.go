package cf

import (
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

	u := New("getiantem.org", os.Getenv("CF_USER"), os.Getenv("CF_API_KEY"))
	for i := 0; i < 10; i++ {
		recs, err := u.GetAllRecords()
		if assert.NoError(t, err, "Should be able to get all records") {
			for _, r := range recs {
				log.Tracef("%v : %v", r.Domain, r.Value)
			}
			assert.True(t, len(recs) > 0, "There should be some records")
		}
		time.Sleep(100 * time.Millisecond)
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func TestFallbacks(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}

	u := New("getiantem.org", os.Getenv("CF_USER"), os.Getenv("CF_API_KEY"))
	recs, err := u.GetRotationRecords("fallbacks")
	if assert.NoError(t, err, "Should be able to get fallbacks rotation") {
		for _, r := range recs {
			log.Tracef("%v : %v", r.Domain, r.Value)
		}
		assert.True(t, len(recs) > 0, "There should be fallback records")
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func TestRegister(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}

	u := New("getiantem.org", os.Getenv("CF_USER"), os.Getenv("CF_API_KEY"))
	for i := 0; i < 10; i++ {
		rec, err := u.Register("cf-test-entry", "127.0.0.1")
		if assert.NoError(t, err, "Should be able to register") {
			err := u.DestroyRecord(rec)
			assert.NoError(t, err, "Should be able to destroy record")
		}
		time.Sleep(100 * time.Millisecond)
	}

	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}
