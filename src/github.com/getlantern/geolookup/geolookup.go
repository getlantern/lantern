package geolookup

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/getlantern/golog"
)

const (

	// The CloudFlare endpoint can only be hit via chained proxies because domain
	// fronting no longer works there.
	cloudflareEndpoint = `http://geo.getiantem.org/lookup/%s`

	// The CloudFront endpoint is used for "direct" domain fronted requests.
	cloudfrontEndpoint = `http://d3u5fqukq7qrhd.cloudfront.net/lookup/%s`
)

var (
	log = golog.LoggerFor("geolookup")
)

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

// LookupIP looks up the given IP using a geolocation service and returns a
// City struct. The http.RoundTripper is required.
func LookupIP(ipAddr string, rt http.RoundTripper) (*City, string, error) {
	return LookupIPWithEndpoint(cloudflareEndpoint, ipAddr, rt)
}

// LookupIPWithEndpoint looks up the given IP using a geolocation service and
// returns a City struct. The http.RoundTripper is required.
func LookupIPWithEndpoint(endpoint string, ipAddr string, rt http.RoundTripper) (*City, string, error) {
	var err error
	var req *http.Request
	var resp *http.Response
	lookupURL := fmt.Sprintf(endpoint, ipAddr)

	if req, err = http.NewRequest("GET", lookupURL, nil); err != nil {
		return nil, "", fmt.Errorf("Could not create request: %q", err)
	}

	frontedUrl := fmt.Sprintf(cloudfrontEndpoint, ipAddr)

	req.Header.Set("Accept", "application/json")
	req.Header.Set("Lantern-Fronted-URL", frontedUrl)
	log.Debugf("Fetching ip...")
	if resp, err = rt.RoundTrip(req); err != nil {
		return nil, "", fmt.Errorf("Could not get response from server: %q", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close reponse body: %v", err)
		}
	}()

	if resp.StatusCode != http.StatusOK {
		return nil, "", fmt.Errorf("Unexpected response status %d", resp.StatusCode)
	}

	ip := resp.Header.Get("X-Reflected-Ip")

	decoder := json.NewDecoder(resp.Body)

	city := &City{}
	if err = decoder.Decode(city); err != nil {
		return nil, ip, err
	}

	log.Debugf("Successfully looked up IP '%v' and country '%v'", ip, city.Country.IsoCode)
	return city, ip, nil
}
