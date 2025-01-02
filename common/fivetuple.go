package common

import (
	"net"
	"net/netip"
)

type FiveTuple struct {
	Network string
	DstIP   netip.Addr
	DstPort uint16
	SrcIP   netip.Addr
	SrcPort uint16
}

func (t *FiveTuple) DestinationAddrPort() netip.AddrPort {
	return netip.AddrPortFrom(t.DstIP, t.DstPort)
}

func (t *FiveTuple) RemoteAddress() string {
	return t.DestinationAddrPort().String()
}

func (t *FiveTuple) UDPAddr() *net.UDPAddr {
	if t.Network != "udp" || !t.DstIP.IsValid() {
		return nil
	}
	return net.UDPAddrFromAddrPort(t.DestinationAddrPort())
}

func (m *FiveTuple) SourceAddrPort() netip.AddrPort {
	return netip.AddrPortFrom(m.SrcIP, m.SrcPort)
}

func (m *FiveTuple) SourceAddress() string {
	return m.SourceAddrPort().String()
}
