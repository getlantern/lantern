// package interceptor which intercepts and forwards traffic between
// a VPN tun interface (typically established via Android VpnService)
// and Lantern
package interceptor

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
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
	// Connection map of TCP streams
	// id based on 5-tuple
	conns map[string]*ProxyConn
	// callback to write packet back over tunnel
	writePacket func([]byte)
	// if request corresponds to a masquerade check
	isMasquerade func(string) bool
	// Address Lantern local proxy is running on
	lanternAddr string

	// whether or not to print all incoming packets
	logPackets bool
}

type Packet struct {
	packet      gopacket.Packet
	destination string
	source      string
	protocol    string

	sourcePort int
	dstPort    int

	size int
	data []byte
}

type ProxyConn struct {
	id        string
	proxyAddr string

	Conn  net.Conn
	pConn *protected.ProtectedConn
}

func (i *Interceptor) openConnection(id, addr string) (*ProxyConn, error) {
	var err error
	pc := &ProxyConn{
		id:        id,
		proxyAddr: addr,
	}

	// we haven't opened an outbound connection
	// to this destination yet. Do so now then write the data
	pc.pConn, err = protected.New(i.protector, i.lanternAddr)
	if err != nil {
		log.Errorf("Error creating protected connection! %s", err)
		return nil, err
	}
	pc.Conn, err = pc.pConn.Dial()
	if err != nil {
		log.Errorf("Could not connect to new proxy connection: %v", err)
		return nil, err
	}

	log.Debugf("Creating CONNECT request to %s with id %s", addr, id)
	connReq := &http.Request{
		Method: "CONNECT",
		URL:    &url.URL{Opaque: pc.proxyAddr},
		Host:   addr,
		Header: make(http.Header),
	}
	connReq.Write(pc.Conn)

	br := bufio.NewReader(pc.Conn)
	resp, err := http.ReadResponse(br, connReq)

	if err != nil {
		log.Errorf("Error processing CONNECT response: %v", err)
		pc.Conn.Close()
		return nil, err
	}
	if resp.StatusCode == 200 {
		log.Debugf("Successfully established an HTTP tunnel with remote end-point: %s", addr)

		if err := pc.Conn.(*net.TCPConn).SetKeepAlive(true); err != nil {
			log.Errorf("Could not set keep alive on connection: %s", addr)
		}
		go i.Read(pc)
		return pc, nil
	}
	return nil, fmt.Errorf("Error creating new proxy connection: %v", err)
}

func (i *Interceptor) Read(pc *ProxyConn) {
	for {
		data := make([]byte, _READ_BUF)
		_, err := pc.Conn.Read(data)
		if err != nil {
			if err != io.EOF {
				pc.Conn.Close()
				i.conns[pc.id] = nil
				log.Errorf("Got non-EOF error: %v", err)
				return
			} else {
				log.Debugf("Received err denoting end of stream: %v", err)
				return
			}
		}
	}
}

func New(protector protected.SocketProtector, logPackets bool,
	lanternAddr string,
	writePacket func([]byte), isMasquerade func(string) bool) *Interceptor {
	i := &Interceptor{
		protector:    protector,
		lanternAddr:  lanternAddr,
		logPackets:   logPackets,
		writePacket:  writePacket,
		isMasquerade: isMasquerade,
		conns:        make(map[string]*ProxyConn),
	}
	log.Debugf("Configured interceptor; Ready to consume packets!")
	return i
}

func createPacket(b []byte) (*Packet, error) {
	packet := gopacket.NewPacket(b, layers.LayerTypeIPv4,
		gopacket.Default)
	if err := packet.ErrorLayer(); err != nil {
		log.Errorf("Error decoding some part of the packet:", err)
		return nil, err.Error()
	}
	p := &Packet{
		size:   len(b),
		packet: packet,
	}

	//  Get the TCP layer from this packet
	if tcpLayer := packet.Layer(layers.LayerTypeTCP); tcpLayer != nil {
		// Get actual TCP data from this layer
		tcp, _ := tcpLayer.(*layers.TCP)
		p.dstPort = int(tcp.DstPort)
		p.sourcePort = int(tcp.SrcPort)
		p.protocol = "tcp"
	}
	if udpLayer := packet.Layer(layers.LayerTypeUDP); udpLayer != nil {
		udp, _ := udpLayer.(*layers.UDP)
		p.dstPort = int(udp.DstPort)
		p.sourcePort = int(udp.SrcPort)
		p.protocol = "udp"
	}
	// Get designated endpoints for this packet
	netFlow := packet.NetworkLayer().NetworkFlow()
	src, dst := netFlow.Endpoints()
	p.destination = dst.String()
	p.source = src.String()
	p.data = b

	return p, nil
}

func (i *Interceptor) hasMasqAddr(p *Packet) bool {
	return i.isMasquerade(p.destination)
}

// forwardPacket checks the connections map for the
// corresponding TCP connection. If it doesn't exist,
// an initial connect request is made using the HTTP CONNECT
// method
func (i *Interceptor) forwardPacket(p *Packet) error {

	addr := fmt.Sprintf("%s:%d", p.destination, p.dstPort)
	id := fmt.Sprintf("%s:%d:%s", p.source,
		p.sourcePort, addr)
	if i.conns[id] == nil {
		// we haven't seen this 5-tuple before
		// open a TCP stream and forward any future
		// packets along it
		conn, err := i.openConnection(id, addr)
		if err != nil {
			log.Errorf("Error creating proxy connection: %v", err)
			return err
		}
		i.conns[id] = conn
	}
	// write the packet to the outbound TCP connection
	bytes, err := i.conns[id].Conn.Write(p.data)
	if err != nil {
		log.Errorf("Could not write packet to connection for addr: %s",
			addr)
		return err
	}
	log.Debugf("Wrote %d bytes to connection %s", bytes, addr)
	return nil
}

// Process takes a new Packet and writes it to its corresponding TCP stream
func (i *Interceptor) Process(b []byte) error {

	p, err := createPacket(b)
	if err != nil {
		log.Errorf("Error creating packet: %v", err)
		return err
	}

	if !p.isTCPPacket() {
		log.Debugf("Unusuable packet; skipping..")
		return nil
	}

	if i.hasMasqAddr(p) {
		// skip masquerade checks
	} else {
		log.Debugf("Got a new packet: %s", p.packet.String())
		err := i.forwardPacket(p)
		if err != nil {
			log.Errorf("Unable to forward new packet: %v", err)
		}

	}
	return nil
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
