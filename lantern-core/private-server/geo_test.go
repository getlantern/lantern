package privateserver

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

const amsterdamLookupResponse = `{
	"City": {"Names": {"en": "Amsterdam"}, "GeoNameID": 2759794},
	"Country": {"Names": {"en": "The Netherlands", "de": "Niederlande"}, "IsoCode": "NL", "GeoNameID": 2750405},
	"Subdivisions": [{"Names": {"en": "North Holland"}, "IsoCode": "NH", "GeoNameID": 2749879}]
}`

const londonLookupResponse = `{
	"Country": {"Names": {"en": "United Kingdom"}, "IsoCode": "GB"},
	"Subdivisions": [
		{"Names": {"en": "England"}, "IsoCode": "ENG"},
		{"Names": {"en": "Barnet"}, "IsoCode": "BNE"}
	]
}`

const countryOnlyLookupResponse = `{
	"City": {"Names": null, "GeoNameID": 0},
	"Country": {"Names": {"en": "United States"}, "IsoCode": "US"},
	"Subdivisions": null
}`

const unknownLookupResponse = `{
	"Country": {"Names": null, "IsoCode": ""},
	"Subdivisions": null
}`

func withGeoLookupServer(t *testing.T, handler http.HandlerFunc) {
	t.Helper()
	srv := httptest.NewTLSServer(handler)
	t.Cleanup(srv.Close)

	origURL, origClient := geoLookupURL, geoLookupClient
	geoLookupURL = srv.URL + "/lookup/"
	client := srv.Client()
	client.CheckRedirect = origClient.CheckRedirect
	geoLookupClient = client
	t.Cleanup(func() {
		geoLookupURL, geoLookupClient = origURL, origClient
	})
}

func TestGetGeoInfo(t *testing.T) {
	tests := []struct {
		name     string
		ip       string
		status   int
		body     string
		expected string
	}{
		{"region and country", "2.16.6.1", http.StatusOK, amsterdamLookupResponse, "North Holland - The Netherlands [NL]"},
		{"uses top-level subdivision", "81.2.69.160", http.StatusOK, londonLookupResponse, "England - United Kingdom [GB]"},
		{"country only", "8.8.8.8", http.StatusOK, countryOnlyLookupResponse, " - United States [US]"},
		{"ipv6", "2001:4860:4860::8888", http.StatusOK, countryOnlyLookupResponse, " - United States [US]"},
		{"unknown country", "10.0.0.1", http.StatusOK, unknownLookupResponse, ""},
		{"error status", "8.8.8.8", http.StatusInternalServerError, "oops", ""},
		{"malformed body", "8.8.8.8", http.StatusOK, "{not json", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var gotPath string
			withGeoLookupServer(t, func(w http.ResponseWriter, r *http.Request) {
				gotPath = r.URL.Path
				w.WriteHeader(tt.status)
				_, _ = w.Write([]byte(tt.body))
			})

			if got := getGeoInfo(tt.ip); got != tt.expected {
				t.Errorf("getGeoInfo(%q) = %q, want %q", tt.ip, got, tt.expected)
			}
			if want := "/lookup/" + tt.ip; gotPath != want {
				t.Errorf("request path = %q, want %q", gotPath, want)
			}
		})
	}
}

func TestGetGeoInfoRejectsInvalidIP(t *testing.T) {
	called := false
	withGeoLookupServer(t, func(w http.ResponseWriter, r *http.Request) {
		called = true
	})

	for _, ip := range []string{"", "not-an-ip", "1.2.3.4/../../admin", "example.com"} {
		if got := getGeoInfo(ip); got != "" {
			t.Errorf("getGeoInfo(%q) = %q, want empty", ip, got)
		}
	}
	if called {
		t.Error("invalid IPs must not reach the geo service")
	}
}

func TestGetGeoInfoDoesNotFollowRedirects(t *testing.T) {
	plain := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("redirect to cleartext URL was followed: %s", r.URL)
		_, _ = w.Write([]byte(amsterdamLookupResponse))
	}))
	t.Cleanup(plain.Close)

	withGeoLookupServer(t, func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, plain.URL+r.URL.Path, http.StatusFound)
	})

	if got := getGeoInfo("2.16.6.1"); got != "" {
		t.Errorf("getGeoInfo after redirect = %q, want empty", got)
	}
}

func TestGeoLookupUsesHTTPS(t *testing.T) {
	if want := "https://geo.getiantem.org/lookup/"; geoLookupURL != want {
		t.Errorf("geoLookupURL = %q, want %q", geoLookupURL, want)
	}
}
