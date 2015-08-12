package main

import (
	"github.com/getlantern/flashlight/client"
	"reflect"
	"testing"
)

func TestJSONloading(t *testing.T) {
	fallbacks := loadFallbacks("test.json")

	expectedFb := []client.ChainedServerInfo{
		{
			Addr:      "78.62.239.134:443",
			Cert:      "-----CERTIFICATE-----\n",
			AuthToken: "a1",
		},
		{
			Addr:      "178.62.239.34:80",
			Cert:      "-----CERTIFICATE-----\n",
			AuthToken: "a2",
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
