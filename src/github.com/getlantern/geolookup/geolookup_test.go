package geolookup

import (
	"fmt"
	"net"
	"net/http"
	"testing"

	"github.com/getlantern/testify/assert"
)

func TestCityLookup(t *testing.T) {
	city, err := LookupIPWithClient("198.199.72.101", nil)
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

	_, err := LookupIPWithClient("", client)
	assert.Error(t, err, "Using bad client should have resulted in error")
}
