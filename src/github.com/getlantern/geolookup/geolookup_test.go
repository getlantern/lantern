package geolookup

import (
	"fmt"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/fronted"

	"github.com/stretchr/testify/assert"
)

func TestCityLookup(t *testing.T) {
	client := &http.Client{}
	city, _, err := LookupIPWithClient("198.199.72.101", client)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])

	}

	// Now test with direct domain fronting.
	fronted.ConfigureForTest(t)
	client = fronted.NewDirectHttpClient(30 * time.Second)
	cloudfrontEndpoint := `http://d3u5fqukq7qrhd.cloudfront.net/lookup/%v`

	log.Debugf("Looking up IP with CloudFront")
	city, _, err = LookupIPWithEndpoint(cloudfrontEndpoint, "198.199.72.101", client)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])
	}
}

func TestNonDefaultClient(t *testing.T) {
	// Set up a client that will fail
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return nil, fmt.Errorf("Failing intentionally")
			},
		},
	}

	_, _, err := LookupIPWithClient("", client)
	assert.Error(t, err, "Using bad client should have resulted in error")
}
