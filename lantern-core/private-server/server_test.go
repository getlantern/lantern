package privateserver

import "testing"

func TestParseInviteURL(t *testing.T) {
	want := Invite{IP: "137.184.162.106", Port: "50733", Token: "tok", Name: "ps-test"}
	tests := []struct {
		name string
		in   string
		want Invite
		ok   bool
	}{
		{"app form", "lantern//private-server?ip=137.184.162.106&port=50733&token=tok&name=ps-test&alias=ps-test&exp=1", want, true},
		{"https form", "https://lantern.io/private-server?ip=137.184.162.106&port=50733&token=tok&name=ps-test", want, true},
		{"scheme form", "lantern://private-server?ip=137.184.162.106&port=50733&token=tok&name=ps-test", want, true},
		{"nickname from join screen", "lantern//private-server?ip=137.184.162.106&port=50733&token=tok&name=My+Toronto+box&alias=ps-test", Invite{IP: "137.184.162.106", Port: "50733", Token: "tok", Name: "My Toronto box"}, true},
		{"alias fallback", "lantern//private-server?ip=137.184.162.106&port=50733&token=tok&alias=ps-test", want, true},
		{"ip fallback", "lantern//private-server?ip=137.184.162.106&port=50733&token=tok", Invite{IP: "137.184.162.106", Port: "50733", Token: "tok", Name: "137.184.162.106"}, true},
		{"missing token", "lantern//private-server?ip=137.184.162.106&port=50733", Invite{}, false},
		{"proxy url", "ss://YWVzLTEyOC1nY206dGVzdA@1.2.3.4:8388#tag", Invite{}, false},
		{"near-miss path", "https://lantern.io/not-private-server?ip=137.184.162.106&port=50733&token=tok", Invite{}, false},
		{"near-miss host", "lantern://private-server-foo?ip=137.184.162.106&port=50733&token=tok", Invite{}, false},
		{"empty", "", Invite{}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := ParseInviteURL(tt.in)
			if ok != tt.ok || got != tt.want {
				t.Errorf("ParseInviteURL(%q) = %+v, %v; want %+v, %v", tt.in, got, ok, tt.want, tt.ok)
			}
		})
	}
}

func TestParseLocation(t *testing.T) {
	tests := []struct {
		name                  string
		in                    string
		region, city, country string
	}{
		{"digitalocean", "nyc3 - new-york-city [US]", "nyc3", "New York City", "US"},
		{"digitalocean uppercase city", "sgp1 - SG [SG]", "sgp1", "SG", "SG"},
		{"gcp zone", "us-central1-a - iowa [US]", "us-central1-a", "Iowa", "US"},
		{"gcp hyphenated city", "europe-west3-b - frankfurt [DE]", "europe-west3-b", "Frankfurt", "DE"},
		{"garbage", "not a location", "", "", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			region, city, country := ParseLocation(tt.in)
			if region != tt.region || city != tt.city || country != tt.country {
				t.Errorf("ParseLocation(%q) = %q, %q, %q; want %q, %q, %q", tt.in, region, city, country, tt.region, tt.city, tt.country)
			}
		})
	}
}
