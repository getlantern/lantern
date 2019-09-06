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
	var rt http.RoundTripper = &http.Transport{}
	city, _, err := LookupIP("198.199.72.101", rt)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])

	}

	// Now test with direct domain fronting.
	fronted.ConfigureForTest(t)
	rt = fronted.NewDirect(30 * time.Second)
	cloudfrontEndpoint := `http://d3u5fqukq7qrhd.cloudfront.net/lookup/%v`

	log.Debugf("Looking up IP with CloudFront")
	city, _, err = LookupIPWithEndpoint(cloudfrontEndpoint, "198.199.72.101", rt)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])
	}
}

func TestFailingTransport(t *testing.T) {
	// Set up a client that will fail
	rt := &http.Transport{
		Dial: func(network, addr string) (net.Conn, error) {
			return nil, fmt.Errorf("Failing intentionally")
		},
	}

	_, _, err := LookupIP("", rt)
	assert.Error(t, err, "Using bad client should have resulted in error")
}
