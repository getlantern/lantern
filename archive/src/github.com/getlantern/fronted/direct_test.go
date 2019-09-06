package fronted

import (
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func testEq(a, b []*Masquerade) bool {

	if a == nil && b == nil {
		return true
	}

	if a == nil || b == nil {
		return false
	}

	if len(a) != len(b) {
		return false
	}

	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}

	return true
}

func TestDirectDomainFronting(t *testing.T) {
	dir, err := ioutil.TempDir("", "direct_test")
	if !assert.NoError(t, err, "Unable to create temp dir") {
		return
	}
	defer os.RemoveAll(dir)
	cacheFile := filepath.Join(dir, "cachefile")
	doTestDomainFronting(t, cacheFile)
	time.Sleep(defaultCacheSaveInterval * 2)
	// Then try again, this time reusing the existing cacheFile
	doTestDomainFronting(t, cacheFile)
}

func doTestDomainFronting(t *testing.T, cacheFile string) {
	ConfigureCachingForTest(t, cacheFile)
	client := &http.Client{
		Transport: NewDirect(30 * time.Second),
	}
	url := "https://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"
	if resp, err := client.Head(url); err != nil {
		t.Fatalf("Could not get response: %v", err)
	} else {
		if 200 != resp.StatusCode {
			t.Fatalf("Unexpected response status: %v", resp.StatusCode)
		}
	}

	log.Debugf("DIRECT DOMAIN FRONTING TEST SUCCEEDED")
}
