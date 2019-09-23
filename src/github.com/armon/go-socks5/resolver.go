package socks5

import (
	"net"
)

// NameResolver is used to implement custom name resolution
type NameResolver interface {
	Resolve(name string) (net.IP, error)
}

// DNSResolver uses the system DNS to resolve host names
type DNSResolver struct{}

func (d DNSResolver) Resolve(name string) (net.IP, error) {
	addr, err := net.ResolveIPAddr("ip", name)
	if err != nil {
		return nil, err
	}
	return addr.IP, err
}
