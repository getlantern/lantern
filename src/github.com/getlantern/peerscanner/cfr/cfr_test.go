package cfr

import (
	"net/http"
	"os"
	"strings"
	"testing"

	"github.com/satori/go.uuid"

	"github.com/getlantern/aws-sdk-go/gen/cloudfront"
	"github.com/getlantern/fdcount"
	"github.com/getlantern/testify/assert"
)

// DRY: getlantern/cfrjanitor/cfrjanitor.go uses this string to identify test
// distributions for cleaning up
const COMMENT = "TEST -- DELETE"

func TestList(t *testing.T) {
	if true {
		t.Log("We don't currently use peerscanner, so this test is disabled")
		return
	}
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	cfr := getCfr()
	dists, err := ListDistributions(cfr)
	if assert.NoError(t, err, "Should be able to get all distributions") {
		for _, d := range dists {
			log.Tracef("%v : %v (%v)\t\t%v", d.InstanceId, d.Domain, d.Status, d.Comment)
		}
		assert.True(t, len(dists) > 0, "There should be some distributions")
	}
	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func TestCreateAndRefresh(t *testing.T) {
	if true {
		t.Log("We don't currently use peerscanner, so this test is disabled. To reenable, we'll need to delete test distributions to avoid hitting our limit")
		return
	}
	_, counter, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatalf("Unable to get starting fdcount: %v", err)
	}
	cfr := getCfr()
	// Deleting cloudfront distributions is actually quite an involved process.
	// Fortunately, distributions per se cost us nothing.  A separate service
	// will be implemented to delete test and otherwise unused distributions.
	name := uuid.NewV4().String()
	dist, err := CreateDistribution(cfr, name, name+"-grey.flashlightproxy.org", COMMENT)
	assert.NoError(t, err, "Should be able to create distribution")
	assert.Equal(t, "InProgress", dist.Status, "New distribution should have Status: \"InProgress\"")
	assert.Equal(t, dist.Comment, COMMENT, "New distribution should have the comment we've set for it")
	assert.Equal(t, name, dist.InstanceId, "New distribution should have the right InstanceId")
	assert.True(t, strings.HasSuffix(dist.Domain, ".cloudfront.net"), "Domain should be a .cloudfront.net subdomain, not '"+dist.Domain+"'")
	dist.Status = "modified to check it really gets overwritten"
	err = RefreshStatus(cfr, dist)
	assert.NoError(t, err, "Should be able to refresh status")
	// Just check that Status stays a valid one.  Checking that it eventually
	// gets refreshed to "Deployed" would take a few minutes, and thus is out
	// of the scope of this unit test.
	assert.Equal(t, "InProgress", dist.Status, "New distribution should have Status: \"InProgress\" even after refreshing right away")
	assert.NoError(t, counter.AssertDelta(0), "All file descriptors should have been closed")
}

func getCfr() *cloudfront.CloudFront {
	cfrid := os.Getenv("CFR_ID")
	cfrkey := os.Getenv("CFR_KEY")
	if cfrid == "" || cfrkey == "" {
		log.Fatalf("You need to set CFR_ID and CFR_KEY environment variables (e.g. `source <too-few-secrets>/envvars.bash`)")
	}
	client := &http.Client{
		Transport: &http.Transport{
			DisableKeepAlives: true,
		},
	}
	return New(cfrid, cfrkey, client)
}
