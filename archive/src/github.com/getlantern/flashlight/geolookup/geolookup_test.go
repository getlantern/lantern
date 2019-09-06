package geolookup

import (
	"testing"
	"time"

	"github.com/getlantern/fronted"
)

func TestFronted(t *testing.T) {
	fronted.ConfigureForTest(t)
	Refresh()
	country := GetCountry(5 * time.Second)
	ip := GetIP(5 * time.Second)
	if len(country) != 2 {
		t.Fatalf("Bad country %v for ip %v", country, ip)
	}

	if len(ip) < 7 {
		t.Fatalf("Bad IP %s", ip)
	}
}
