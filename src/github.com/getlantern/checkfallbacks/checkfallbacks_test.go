package main

import (
	"reflect"
	"testing"
)

func TestJSONloading(t *testing.T) {
	fallbacks := loadFallbacks("test.json")

	expectedFb := []FallbackServer{
		{
			Protocol: "tcp",
			IP: "78.62.239.134",
			Port: "443",
			Pt: false,
			Cert: "-----CERTIFICATE-----\n",
			Auth_token: "a1",
		},
		{
			Protocol: "udp",
			IP: "178.62.239.34",
			Port: "80",
			Pt: false,
			Cert: "-----CERTIFICATE-----\n",
			Auth_token: "a2",
		},
	}

	if len(expectedFb) != len(fallbacks) {
		t.Error("Expected number of fallbacks mismatch")
	}

	for i, f := range fallbacks {
		if !reflect.DeepEqual(f, expectedFb[i]) {
			t.Fail()
		}
	}
}
