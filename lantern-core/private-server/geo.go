package privateserver

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"time"
)

const geoLookupTimeout = 10 * time.Second

var (
	// geoLookupURL is Lantern's public geolocation service. It answers with a
	// MaxMind GeoIP2 City record for the IP appended to the path.
	geoLookupURL    = "https://geo.getiantem.org/lookup/"
	geoLookupClient = &http.Client{Timeout: geoLookupTimeout}
)

type geoNames struct {
	Names map[string]string `json:"Names"`
}

type geoCountry struct {
	geoNames
	IsoCode string `json:"IsoCode"`
}

type geoInfo struct {
	Country      geoCountry `json:"Country"`
	Subdivisions []geoNames `json:"Subdivisions"`
}

func (n geoNames) english() string {
	return n.Names["en"]
}

// region returns the most general subdivision, e.g. "North Holland" or "England".
func (g geoInfo) region() string {
	if len(g.Subdivisions) == 0 {
		return ""
	}
	return g.Subdivisions[0].english()
}

// getGeoInfo looks up the location of a server IP via Lantern's geolocation
// service and formats it as "<region> - <country> [<country code>]". It
// returns an empty string if the lookup fails.
func getGeoInfo(ip string) string {
	if net.ParseIP(ip) == nil {
		slog.Error("Not fetching geo info for invalid IP", slog.String("ip", ip))
		return ""
	}
	slog.Debug("Fetching geo info for IP", slog.String("ip", ip))
	resp, err := geoLookupClient.Get(geoLookupURL + url.PathEscape(ip))
	if err != nil {
		slog.Error("Error fetching geo info", slog.Any("error", err))
		return ""
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		slog.Error("Unexpected geo info response status", slog.Int("status", resp.StatusCode))
		return ""
	}

	var info geoInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		slog.Error("Error decoding geo info response", slog.Any("error", err))
		return ""
	}
	if info.Country.IsoCode == "" {
		slog.Error("Geo info response has no country", slog.String("ip", ip))
		return ""
	}
	slog.Debug("Geo info for IP", slog.String("ip", ip), slog.Any("info", info))
	return fmt.Sprintf("%s - %s [%s]", info.region(), info.Country.english(), info.Country.IsoCode)
}
