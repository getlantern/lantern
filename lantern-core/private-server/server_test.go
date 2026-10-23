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
