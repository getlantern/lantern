// Package igdman provides a basic management interface for Internet Gateway
// Devices (IGDs), primarily intended to help with creating port mappings from
// external ports to ports on internal ips.
//
// igdman uses either UPnP or NAT-PMP, depending on what's discovered on the
// network.
//
// Internally, igdman uses miniupnpc (https://github.com/miniupnp/miniupnp) and
// go-nat-pmp (https://code.google.com/p/go-nat-pmp/).
//
// Basic Usage:
//
//  igd, err := igdman.NewIGD()
//  if err != nil {
//      log.Fatalf("Unable to get IGD: %s", err)
//  }
//  err := igd.AddPortMapping(TCP, "192.168.1.210", 80, 8080, 0)
//  if err != nil {
//      log.Fatalf("Unable to map port: %s", err)
//  }
//
package igdman

import (
	"log"
	"time"
)

// protocol is TCP or UDP
type protocol string

const (
	TCP = protocol("TCP")
	UDP = protocol("UDP")
)

var (
	opTimeout = 10 * time.Second
)

// Interface IGD represents an Internet Gateway Device.
type IGD interface {
	// GetExternalIP returns the IGD's external (public) IP address
	GetExternalIP() (ip string, err error)

	// AddPortMapping maps the given external port on the IGD to the internal
	// port, with an optional expiration.
	AddPortMapping(proto protocol, internalIP string, internalPort int, externalPort int, expiration time.Duration) error

	// RemovePortMapping removes the mapping from the given external port.
	RemovePortMapping(proto protocol, externalPort int) error
}

// NewIGD obtains a new IGD (either UPnP or NAT-PMP, depending on what's available)
func NewIGD() (igd IGD, err error) {
	igd, err = NewUpnpIGD()
	if err != nil {
		log.Printf("Unable to initialize UPnP IGD, falling back to NAT-PMP: %s", err)
		igd, err = NewNATPMPIGD()
	}
	return
}
