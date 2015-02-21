package geolookup

import (
	"net/http"
	"testing"
)

func TestCityLookup(t *testing.T) {
	var city *City
	var err error

	if city, err = LookupCity("198.199.72.101"); err != nil {
		t.Fatal(err)
	}

	if city.City.Names["en"] != "New York" {
		t.Fatal("Look up failed.")
	}

}

func TestUsingDefaultClient(t *testing.T) {
	if UsesDefaultHTTPClient() == false {
		t.Fatal("Should not happen as we haven't modified the client yet.")
	}

	SetHTTPClient(&http.Client{})

	if UsesDefaultHTTPClient() == true {
		t.Fatal("Should not happen as we changed the client.")
	}

	// A client with the same options as the default client.
	SetHTTPClient(&http.Client{
		Timeout: geoLookupTimeout,
	})

	if UsesDefaultHTTPClient() == true {
		t.Fatal("Should not happen as we changed the client.")
	}

	SetHTTPClient(defaultHttpClient)

	if UsesDefaultHTTPClient() == false {
		t.Fatal("Should not happen as we went back to the default client.")
	}
}
