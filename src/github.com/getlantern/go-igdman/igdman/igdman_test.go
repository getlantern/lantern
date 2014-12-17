package igdman

import (
	"fmt"
	"net"
	"os"
	"testing"

	"github.com/getlantern/framed"
)

var (
	PUBLIC_IP = "PUBLIC_IP"
)

func TestExternalIP_UPnP(t *testing.T) {
	doTestExternalIP(t, getUPnPIGD(t))
}

func TestMapping_UPnP(t *testing.T) {
	doTestMapping(t, getUPnPIGD(t))
}

func TestFailedAddMapping_UPnP(t *testing.T) {
	doTestFailedAddMapping(t, getUPnPIGD(t))
}

func TestFailedRemoveMapping_UPnP(t *testing.T) {
	doTestFailedRemoveMapping(t, getUPnPIGD(t))
}

func TestExternalIP_NATPMP(t *testing.T) {
	doTestExternalIP(t, getNATPMPIGD(t))
}

func TestMapping_NATPMP(t *testing.T) {
	doTestMapping(t, getNATPMPIGD(t))
}

func TestFailedAddMapping_NATPMP(t *testing.T) {
	doTestFailedAddMapping(t, getNATPMPIGD(t))
}

func TestFailedRemoveMapping_NATPMP(t *testing.T) {
	doTestFailedRemoveMapping(t, getNATPMPIGD(t))
}

func getUPnPIGD(t *testing.T) IGD {
	igd, err := NewUpnpIGD()
	if err != nil {
		t.Fatalf("Unable to create UPnPIGD: %s", err)
	}
	return igd
}

func getNATPMPIGD(t *testing.T) IGD {
	igd, err := NewNATPMPIGD()
	if err != nil {
		t.Fatalf("Unable to create NATPMPIGD: %s", err)
	}
	return igd
}

// TestExternalIP only works when there is a valid IGD device with an external
// IP.  The environment variable EXTERNAL_IP needs to be set for this test to
// work.
func doTestExternalIP(t *testing.T, igd IGD) {
	expectedExternalIP := os.Getenv("EXTERNAL_IP")
	if expectedExternalIP == "" {
		t.Fatalf("Please set the environment variable EXTERNAL_IP to provide your expected public IP address")
	}

	publicIp, err := igd.GetExternalIP()
	if err != nil {
		t.Fatalf("Unable to get Public IP: %s", err)
	}
	if publicIp != expectedExternalIP {
		t.Errorf("External ip '%s' did not match expected '%s'", publicIp, expectedExternalIP)
	}
	publicIp, err = igd.GetExternalIP()
	if err != nil {
		t.Fatalf("Unable to get External IP 2nd time: %s", err)
	}
}

func doTestMapping(t *testing.T, igd IGD) {
	port := 15067

	externalIP, err := igd.GetExternalIP()
	if err != nil {
		t.Fatalf("Unable to get external IP: %s", err)
	}

	// Run echo server
	go func() {
		l, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", port))
		defer l.Close()
		if err != nil {
			t.Fatalf("Unable to start server: %s", err)
		}
		for {
			conn, err := l.Accept()
			if err != nil {
				t.Fatalf("Unable to accept connection: %s", err)
			}
			defer conn.Close()
			fr := framed.NewReader(conn)
			fw := framed.NewWriter(conn)
			frame := make([]byte, 1000)
			for {
				n, err := fr.Read(frame)
				if err != nil {
					return
				}
				_, err = fw.Write(frame[:n])
				if err != nil {
					return
				}
			}
		}
	}()

	// Add port mapping
	internalIP, err := getFirstNonLoopbackAdapterAddr()
	if err != nil {
		t.Fatalf("Unable to get internal ip: %s", err)
	}

	err = igd.AddPortMapping(TCP, internalIP, port, port, 0)
	if err != nil {
		t.Fatalf("Unable to add port mapping: %s", err)
	}

	// Run echo client
	conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", externalIP, port))
	if err != nil {
		t.Fatalf("Unable to connect to echo server")
	}
	defer conn.Close()
	fr := framed.NewReader(conn)
	fw := framed.NewWriter(conn)
	testString := "Hello strange port mapped world"
	_, err = fw.Write([]byte(testString))
	if err != nil {
		t.Fatalf("Unable to write to echo server")
	}
	frame := make([]byte, 1000)
	n, err := fr.Read(frame)
	if err != nil {
		t.Fatalf("Unable to read from echo server")
	}
	response := string(frame[:n])
	if response != testString {
		t.Errorf("Response '%s' did not match expected value '%s'", response, testString)
	}

	// Remove port mapping
	err = igd.RemovePortMapping(TCP, port)
	if err != nil {
		t.Fatalf("Unable to remove port mapping: %s", err)
	}
	conn, err = net.Dial("tcp", fmt.Sprintf("%s:%d", externalIP, port))
	if err == nil {
		t.Errorf("Connecting to address with closed port mapping should have resulted in an error")
	}
}

func doTestFailedAddMapping(t *testing.T, igd IGD) {
	port := 15068

	// Add port mapping
	internalIP, err := getFirstNonLoopbackAdapterAddr()
	if err != nil {
		t.Fatalf("Unable to get internal ip: %s", err)
	}

	err = igd.AddPortMapping(TCP, internalIP, port, 0, 0)
	if err == nil {
		t.Error("Adding mapping for bad port should have resulted in error")
	}
}

func doTestFailedRemoveMapping(t *testing.T, igd IGD) {
	err := igd.RemovePortMapping(TCP, -1)
	if err == nil {
		t.Error("Removing mapping for bad port should have resulted in error")
	}
}
