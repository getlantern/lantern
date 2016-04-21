// +build !windows

package igdman

import (
	"fmt"
	"net"
)

func getFirstNonLoopbackAdapterAddr() (string, error) {
	intfs, err := net.Interfaces()
	if err != nil {
		return "", err
	}

	for _, intf := range intfs {
		addrs, err := intf.Addrs()
		if err != nil {
			return "", err
		}

		for _, a := range addrs {
			switch addr := a.(type) {
			case *net.IPNet:
				ip4 := addr.IP.To4()
				if ip4 != nil && !ip4.IsLoopback() {
					return ip4.String(), nil
				}
			}
		}
	}

	return "", fmt.Errorf("No non-loopback adapter found")
}
