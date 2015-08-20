package server

import (
	"net/http"
	"testing"

	"github.com/getlantern/fronted"
)

func TestBanned(t *testing.T) {

	srv := &Server{
		Addr:         "127.0.0.1",
		ReadTimeout:  0, // don't timeout
		WriteTimeout: 0,
		CertContext:  &fronted.CertContext{},
		AllowedPorts: []int{80, 443, 8080, 8443, 5222, 5223, 5228},

		// We've observed high resource consumption from these countries for
		// purposes unrelated to Lantern's mission, so we disallow them.
		BannedCountries: []string{"PH"},
	}

	req, err := http.NewRequest("GET", "http://test.com/foo", nil)
	if err != nil {
		log.Fatal(err)
	}
	req.Header.Set("Cf-Ipcountry", "PH")

	err = srv.checkForBannedCountry(req)
	if err == nil {
		t.Fatalf("Should be banned: %v", err)
	}

	req.Header.Set("Cf-Ipcountry", "US")
	err = srv.checkForBannedCountry(req)
	if err != nil {
		t.Fatalf("Should not be banned: %v", err)
	}
}
