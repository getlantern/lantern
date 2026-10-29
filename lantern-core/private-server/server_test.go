package privateserver

import (
	"context"
	"errors"
	"net/http"
	"testing"

	C "github.com/getlantern/common"
)

func TestAddServerManuallyPreservesProvisioningSession(t *testing.T) {
	previous, existed := sessions.Load("provisioner")
	t.Cleanup(func() {
		if existed {
			sessions.Store("provisioner", previous)
		} else {
			sessions.Delete("provisioner")
		}
	})
	withGeoLookupServer(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(amsterdamLookupResponse))
	})
	addErr := errors.New("registration failed")
	for _, tt := range []struct {
		name    string
		active  bool
		joined  bool
		wantErr error
	}{
		{name: "invite during provisioning", active: true, joined: true},
		{name: "failed invite during provisioning", active: true, joined: true, wantErr: addErr},
		{name: "manual registration during provisioning", active: true},
		{name: "invite without provisioning", joined: true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			active := &provisionSession{serverName: "deploying", serverLocation: "nyc3 - new-york-city [US]"}
			if tt.active {
				storeSession(active)
			} else {
				sessions.Delete("provisioner")
			}
			client := &testPrivateServerClient{t: t, joined: tt.joined, err: tt.wantErr}
			if err := AddServerManually("192.0.2.1", "443", "token", "joined", tt.joined, client, nil); !errors.Is(err, tt.wantErr) {
				t.Fatalf("AddServerManually() = %v, want %v", err, tt.wantErr)
			}
			if !client.called {
				t.Fatal("private server was not registered")
			}
			got, found := sessions.Load("provisioner")
			if found != tt.active || tt.active && got != active {
				t.Fatal("manual registration changed the provisioning session")
			}
		})
	}
}

type testPrivateServerClient struct {
	t      *testing.T
	joined bool
	err    error
	called bool
}

func (c *testPrivateServerClient) AddPrivateServer(_ context.Context, tag, ip string, port int, token string, location C.ServerLocation, joined bool) error {
	c.t.Helper()
	c.called = true
	if tag != "joined" || ip != "192.0.2.1" || port != 443 || token != "token" || joined != c.joined {
		c.t.Fatalf("unexpected registration: tag=%q ip=%q port=%d joined=%t", tag, ip, port, joined)
	}
	if want := (C.ServerLocation{City: "North Holland", Country: "The Netherlands", CountryCode: "NL"}); location != want {
		c.t.Fatalf("location = %+v, want %+v", location, want)
	}
	return c.err
}

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
