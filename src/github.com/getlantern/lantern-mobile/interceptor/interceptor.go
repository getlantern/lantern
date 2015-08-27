// package interceptor which intercepts and forwards traffic between
// a VPN tun interface (typically established via Android VpnService)
// and Lantern
package interceptor

// #cgo LDFLAGS: -I/usr/include

import (
	"fmt"

	"github.com/getlantern/balancer"
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
	"github.com/getlantern/lantern-mobile/tunio"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
)

const (
	_READ_BUF = 1024
)

var (
	log = golog.LoggerFor("lantern-android.interceptor")
)

// Here is the procedure for intercepting and forwarding a packet:
// - lantern is started after the VPN connection is established
// - Configure initializes the packet interception tool
// - Process intercepts an incoming packet as a raw byte array
//   and decodes it using gopacket
// - if its a TCP packet and non-masquerade check, we check
//   the connections map for an existing TCP stream using the
//   5-tuple as key
//   - if a connection does not exist, we open a new protected
//     connection and send an HTTP CONNECT to Lantern for the
//     desired destination to begin tunneling the communication
//   - the packet is forwarded along the corresponding tunnel

type Interceptor struct {
	// Service for excluding TCP connections from VpnService
	protector protected.SocketProtector

	// callback to write packet back over tunnel
	writePacket func([]byte)
	// if request corresponds to a masquerade check
	isMasquerade func(string) bool
	// Address Lantern local proxy is running on
	lanternAddr string

	// whether or not to print all incoming packets
	logPackets bool

	tunio *tunio.TunIO
}

type Packet struct {
	packet      gopacket.Packet
	destination string
	source      string
	protocol    string

	sourcePort int
	dstPort    int

	size int
}

func New(protector protected.SocketProtector, logPackets bool,
	lanternAddr string,
	balancer *balancer.Balancer,
	writePacket func([]byte), isMasquerade func(string) bool) *Interceptor {
	i := &Interceptor{
		protector:    protector,
		lanternAddr:  lanternAddr,
		logPackets:   logPackets,
		writePacket:  writePacket,
		isMasquerade: isMasquerade,
		tunio:        tunio.NewTunIO(balancer),
	}

	log.Debugf("Configured interceptor; Ready to consume packets!")
	return i
}

func (i *Interceptor) hasMasqAddr(p *Packet) bool {
	return i.isMasquerade(p.destination)
}

// Process takes a new Packet and writes it to its corresponding TCP stream
func (i *Interceptor) Process(b []byte) error {

	return i.tunio.HandlePacket(b, i.writePacket)
}

// isTCPPacket checks for a TCP packet
func (p *Packet) isTCPPacket() bool {
	packet := p.packet
	return packet.NetworkLayer() != nil && packet.TransportLayer() != nil &&
		packet.TransportLayer().LayerType() == layers.LayerTypeTCP
}

// Print known details about the Packet
func (p *Packet) Print() {
	log.Debugf("New packet: %s", p.packet.String())
}

func (p *Packet) String() string {
	return fmt.Sprintf("%s %s:%d -> %s:%d",
		p.protocol, p.source, p.sourcePort, p.destination,
		p.dstPort)
}
