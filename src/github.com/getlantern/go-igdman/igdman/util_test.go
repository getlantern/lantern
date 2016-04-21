package igdman

import (
	"os"
	"testing"
)

// TestDefaultGateway requires an environment variable GATEWAY_IP needs to be
// set for this test to work.
func TestDefaultGateway(t *testing.T) {
	ip, err := defaultGatewayIp()
	if err != nil {
		t.Fatalf("Error getting gateway IP: %s", err)
	}
	expectedGatewayIp := os.Getenv("GATEWAY_IP")
	if expectedGatewayIp == "" {
		t.Fatalf("Please set the environment variable GATEWAY_IP to provide your expected Gateway IP address")
	}
	if ip != expectedGatewayIp {
		t.Errorf("Wrong Gateway IP.  Expected: %s, got: %s", expectedGatewayIp, ip)
	}
}
