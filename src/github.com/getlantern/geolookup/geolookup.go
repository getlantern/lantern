package geolookup

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const (
	geoServeEndpoint = `http://geo.getiantem.org/lookup/%s`
	geoLookupTimeout = 20 * time.Second
)

var defaultHttpClient = &http.Client{
	Timeout: geoLookupTimeout,
}

var httpClient = defaultHttpClient

// The City structure corresponds to the data in the GeoIP2/GeoLite2 City
// databases.
type City struct {
	City struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"city"`
	Continent struct {
		Code      string            `maxminddb:"code"`
		GeoNameID uint              `maxminddb:"geoname_id"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"continent"`
	Country struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"country"`
	Location struct {
		Latitude  float64 `maxminddb:"latitude"`
		Longitude float64 `maxminddb:"longitude"`
		MetroCode uint    `maxminddb:"metro_code"`
		TimeZone  string  `maxminddb:"time_zone"`
	} `maxminddb:"location"`
	Postal struct {
		Code string `maxminddb:"code"`
	} `maxminddb:"postal"`
	RegisteredCountry struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"registered_country"`
	RepresentedCountry struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
		Type      string            `maxminddb:"type"`
	} `maxminddb:"represented_country"`
	Subdivisions []struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"subdivisions"`
	Traits struct {
		IsAnonymousProxy    bool `maxminddb:"is_anonymous_proxy"`
		IsSatelliteProvider bool `maxminddb:"is_satellite_provider"`
	} `maxminddb:"traits"`
}

// The Country structure corresponds to the data in the GeoIP2/GeoLite2
// Country databases.
type Country struct {
	Continent struct {
		Code      string            `maxminddb:"code"`
		GeoNameID uint              `maxminddb:"geoname_id"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"continent"`
	Country struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"country"`
	RegisteredCountry struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
	} `maxminddb:"registered_country"`
	RepresentedCountry struct {
		GeoNameID uint              `maxminddb:"geoname_id"`
		IsoCode   string            `maxminddb:"iso_code"`
		Names     map[string]string `maxminddb:"names"`
		Type      string            `maxminddb:"type"`
	} `maxminddb:"represented_country"`
	Traits struct {
		IsAnonymousProxy    bool `maxminddb:"is_anonymous_proxy"`
		IsSatelliteProvider bool `maxminddb:"is_satellite_provider"`
	} `maxminddb:"traits"`
}

// SetHTTPClient defines the client to use for executing HTTP requests.
func SetHTTPClient(client *http.Client) {
	httpClient = client
	httpClient.Timeout = geoLookupTimeout
}

// UsesDefaultHTTPClient returns false when the package is using a different
// client that the default one.
func UsesDefaultHTTPClient() bool {
	return httpClient == defaultHttpClient
}

// LookupCity looks up the given IP using a geolocation service and returns a
// City struct.
func LookupCity(ipAddr string) (*City, error) {
	var err error
	var req *http.Request
	var resp *http.Response

	lookupURL := fmt.Sprintf(geoServeEndpoint, ipAddr)

	if req, err = http.NewRequest("GET", lookupURL, nil); err != nil {
		return nil, fmt.Errorf("Could not create request: %q", err)
	}

	if resp, err = httpClient.Do(req); err != nil {
		return nil, fmt.Errorf("Could not get response from server: %q", err)
	}

	defer resp.Body.Close()

	decoder := json.NewDecoder(resp.Body)

	city := &City{}
	if err = decoder.Decode(city); err != nil {
		return nil, err
	}

	return city, nil
}
