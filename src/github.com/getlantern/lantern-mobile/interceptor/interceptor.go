package interceptor

import (
	"fmt"

	"github.com/getlantern/golog"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
)

var (
	log = golog.LoggerFor("lantern-android.interceptor")
)

type Envelope struct {
	packet      gopacket.Packet
	destination string
	source      string
	protocol    string
	sourcePort  int
	dstPort     int
	length      int
}

func (e *Envelope) GetPort() int {
	return e.dstPort
}

func (e *Envelope) GetDestination() string {
	return e.destination
}

func (e *Envelope) Print() {
	log.Debugf("New packet: %s", e.packet.String())
}

func (e *Envelope) GetProtocol() string {
	return e.protocol
}

func (e *Envelope) String() string {
	return fmt.Sprintf("%s %s:%d -> %s:%d length: %d",
		e.protocol, e.source, e.sourcePort, e.destination,
		e.dstPort, e.length)
}

func NewPacket(b []byte) (*Envelope, error) {
	e := new(Envelope)
	e.length = len(b)
	packet := gopacket.NewPacket(b, layers.LayerTypeIPv4, gopacket.Default)
	if err := packet.ErrorLayer(); err != nil {
		log.Errorf("Error decoding some part of the packet:", err)
		return nil, err.Error()
	}
	//  Get the TCP layer from this packet
	if tcpLayer := packet.Layer(layers.LayerTypeTCP); tcpLayer != nil {
		// Get actual TCP data from this layer
		tcp, _ := tcpLayer.(*layers.TCP)
		e.dstPort = int(tcp.DstPort)
		e.sourcePort = int(tcp.SrcPort)
		e.protocol = "tcp"
	}
	if udpLayer := packet.Layer(layers.LayerTypeUDP); udpLayer != nil {
		udp, _ := udpLayer.(*layers.UDP)
		e.dstPort = int(udp.DstPort)
		e.sourcePort = int(udp.SrcPort)
		e.protocol = "udp"
	}
	// Get designated endpoints for this packet
	netFlow := packet.NetworkLayer().NetworkFlow()
	src, dst := netFlow.Endpoints()
	e.destination = dst.String()
	e.source = src.String()
	log.Debugf("New packet: %s", e.String())
	return e, nil
}
