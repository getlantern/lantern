package igdman

import (
	"fmt"
	"net"
	"os"
)

func getFirstNonLoopbackAdapterAddr() (string, error) {
	name, err := os.Hostname()
	if err != nil {
		return "", err
	}

	addrs, err := net.LookupHost(name)
	if err != nil {
		return "", err
	}

	for _, a := range addrs {
		ip := net.ParseIP(a)
		ip4 := ip.To4()
		if ip4 != nil && !ip.IsLoopback() {
			return ip4.String(), nil
		}
	}

	return "", fmt.Errorf("No non-loopback adapter found")
}
