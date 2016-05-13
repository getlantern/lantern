package fronted

import (
	"net/http"
	"testing"
	"time"
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
	ConfigureForTest(t)
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
