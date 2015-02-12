package cfr

import (
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/satori/go.uuid"

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

func TestCreateAndRefresh(t *testing.T) {
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	cfr := New(os.Getenv("CFR_ID"), os.Getenv("CFR_KEY"), httpClientWithDisabledKeepAlives())
	// Deleting cloudfront distributions is actually quite an involved process.
	// Fortunately, distributions per se cost us nothing.  A separate service
	// will be implemented to delete test and otherwise unused distributions.
	name := uuid.NewV4().String()
	dist, err := CreateDistribution(cfr, name, name+"-grey.flashlightproxy.org", "TEST -- DELETE")
	assert.NoError(t, err, "Should be able to create distribution")
	assert.Equal(t, "InProgress", dist.Status, "New distribution should have Status: \"InProgress\"")
	assert.Equal(t, name, dist.InstanceId, "New distribution should have the right InstanceId")
	assert.True(t, strings.HasSuffix(dist.Domain, ".cloudfront.net"), "Domain should be a .cloudfront.net subdomain, not '"+dist.Domain+"'")
	err = RefreshStatus(cfr, dist)
	assert.NoError(t, err, "Should be able to refresh status")
	// Just check that Status stays a valid one.  Checking that it eventually
	// gets refreshed to "Deployed" would take a few minutes, and thus is out
	// of the scope of this unit test.
	assert.Equal(t, "InProgress", dist.Status, "New distribution should have Status: \"InProgress\" even after refreshing right away")
	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func httpClientWithDisabledKeepAlives() *http.Client {
	return &http.Client{
		Transport: &http.Transport{
			DisableKeepAlives: true,
		},
	}
}
