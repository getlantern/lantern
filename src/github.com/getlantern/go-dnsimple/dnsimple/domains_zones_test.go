package dnsimple

import (
	"fmt"
	"net/http"
	"reflect"
	"testing"
)

func TestDomainsService_GetZone(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/domains/example.com/zone", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		fmt.Fprint(w, `{"zone":"$ORIGIN example-1417880719.com.\n$TTL 1h\nexample-1417880719.com. 3600 IN SOA ns1.dnsimple.com. admin.dnsimple.com. 2014120601 86400 7200 604800 300\nexample-1417880719.com. 3600 IN NS ns2.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns1.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns3.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns4.dnsimple.com.\n"}`)
	})

	zone, _, err := client.Domains.GetZone("example.com")

	if err != nil {
		t.Errorf("Zones.Get returned error: %v", err)
	}

	want := "$ORIGIN example-1417880719.com.\n$TTL 1h\nexample-1417880719.com. 3600 IN SOA ns1.dnsimple.com. admin.dnsimple.com. 2014120601 86400 7200 604800 300\nexample-1417880719.com. 3600 IN NS ns2.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns1.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns3.dnsimple.com.\nexample-1417880719.com. 3600 IN NS ns4.dnsimple.com.\n"
	if !reflect.DeepEqual(zone, want) {
		t.Errorf("Zones.Get returned %+v, want %+v", zone, want)
	}
}
