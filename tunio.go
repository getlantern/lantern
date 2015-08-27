package tunio

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"io"
	"log"
	"math/rand"
	"net"
	"sync"
)

const (
	ipMaxDatagramSize  = 576
	tcpMaxDatagramSize = ipMaxDatagramSize - 40
)

type node struct {
	ip   net.IP
	port layers.TCPPort
}

type srcNode struct {
	node
}
type dstNode struct {
	node
}

func (n *node) String() string {
	return fmt.Sprintf("%s:%d", n.ip.String(), n.port)
}

var (
	fwdSockets map[string]map[string]*RawSocketServer
)

type Status uint

const (
	StatusClientSYN uint = iota
	StatusServerSYNACK
	StatusClientACK
	StatusEstablished
	StatusClosing
	StatusWaitClose
)

type RawSocketServer struct {
	connOut net.Conn
	step    uint
	zero    uint32
	seq     uint32
	ack     uint32
	src     *srcNode
	dst     *dstNode

	r *bufio.Reader
	w *bufio.Writer

	wb *bytes.Buffer

	writeLock bool
	writeMu   sync.Mutex

	window uint16

	ipLayer *layers.IPv4

	relayPacket func([]byte)
}

func init() {
	fwdSockets = make(map[string]map[string]*RawSocketServer)
}

type dialer interface {
	Dial(network, address string) (net.Conn, error)
}

type TunIO struct {
	dialer dialer
}

func NewTunIO(d dialer) *TunIO {
	return &TunIO{
		dialer: d,
	}
}

func (r *RawSocketServer) Write(message []byte) (n int, err error) {
	var messages int
	l := len(message)
	for i := 0; i < l; i += tcpMaxDatagramSize {
		push := false

		j := tcpMaxDatagramSize
		if i+j > l {
			j = l - i
			push = true
		}

		if messages%8 == 7 {
			push = true
		}

		if err = r.sendPayload(message[i:i+j], push); err != nil {
			return
		}
		n += j

		messages++
	}
	return
}

func (r *RawSocketServer) sendPayload(rawBytes []byte, push bool) error {
	if r.step != StatusEstablished {
		return errors.New("Can't send data while opening or closing connection.")
	}

	if len(rawBytes) > tcpMaxDatagramSize {
		return fmt.Errorf("Can't sent datagram larger than %d", tcpMaxDatagramSize)
	}

	r.writeMu.Lock()
	r.writeLock = true

	// Answering with SYN-ACK
	tcpLayer := &layers.TCP{
		ACK: true,
		PSH: push,
	}

	if err := r.injectPacketFromDst(tcpLayer, rawBytes); err != nil {
		return err
	}

	r.incrServerSeq(uint32(len(rawBytes)))

	return nil
}

func (r *RawSocketServer) replyFINACK() error {
	if r.step != StatusClosing {
		return errors.New("Can't FIN-ACK on a non-closing connection.")
	}

	// Answering with SYN-ACK
	tcpLayer := &layers.TCP{
		ACK: true,
		FIN: true,
	}

	if err := r.injectPacketFromDst(tcpLayer, nil); err != nil {
		return err
	}

	// Expecting this seq number.
	r.incrServerSeq(1)
	return nil
}

func (r *RawSocketServer) replyACK(seq uint32, incr uint32) error {
	if r.step != StatusEstablished {
		return errors.New("Can't ACK on a non-established connection.")
	}

	r.ack = seq + incr

	// Answering with SYN-ACK
	tcpLayer := &layers.TCP{
		ACK: true,
	}

	if err := r.injectPacketFromDst(tcpLayer, nil); err != nil {
		return err
	}

	return nil
}

func (r *RawSocketServer) replySYNACK(seq uint32) error {
	if r.step != StatusClientSYN {
		return errors.New("Unexpected SYN.")
	}

	r.step = StatusServerSYNACK
	r.zero = randomSeqNumber()

	r.ack = seq + 1
	r.seq = r.zero

	// Answering with SYN-ACK
	tcpLayer := &layers.TCP{
		ACK: true,
		SYN: true,
	}

	if err := r.injectPacketFromDst(tcpLayer, nil); err != nil {
		return err
	}

	// Expecting this seq number.
	r.incrServerSeq(1)
	return nil
}

func (r *RawSocketServer) relativeSeq(i uint32) uint32 {
	if i >= r.zero {
		return i - r.zero
	}
	return 0
}

func (r *RawSocketServer) incrServerSeq(i uint32) {
	r.seq = r.seq + i
}

func (r *RawSocketServer) injectPacketFromDst(tcpLayer *layers.TCP, rawBytes []byte) error {
	// Preparing ipLayer.
	ipLayer := &layers.IPv4{
		SrcIP:    r.dst.ip,
		DstIP:    r.src.ip,
		Version:  4,
		TTL:      64,
		Protocol: layers.IPProtocolTCP,
	}

	options := gopacket.SerializeOptions{
		ComputeChecksums: true,
		FixLengths:       true,
	}

	tcpLayer.SrcPort = r.dst.port
	tcpLayer.DstPort = r.src.port
	tcpLayer.Window = r.window

	tcpLayer.Ack = r.ack
	tcpLayer.Seq = r.seq

	tcpLayer.SetNetworkLayerForChecksum(ipLayer)

	// And create the packet with the layers
	buffer := gopacket.NewSerializeBuffer()
	gopacket.SerializeLayers(buffer, options,
		ipLayer,
		tcpLayer,
		gopacket.Payload(rawBytes),
	)

	outgoingPacket := buffer.Bytes()

	r.replyPacket(outgoingPacket)

	return nil
}

func (t *TunIO) HandlePacket(b []byte, relayPacket func([]byte)) error {

	// Decoding TCP/IP
	decoded := gopacket.NewPacket(
		b,
		layers.LayerTypeIPv4,
		gopacket.Default,
	)

	if err := decoded.ErrorLayer(); err != nil {
		return err.Error()
	}

	if decoded.NetworkLayer() == nil || decoded.TransportLayer() == nil ||
		decoded.TransportLayer().LayerType() != layers.LayerTypeTCP {
		return nil
	}

	var ip *layers.IPv4
	var tcp *layers.TCP

	// Get the IP layer.
	if ipLayer := decoded.Layer(layers.LayerTypeIPv4); ipLayer != nil {
		ip, _ = ipLayer.(*layers.IPv4)
	}

	// Get the TCP layer from this decoded
	if tcpLayer := decoded.Layer(layers.LayerTypeTCP); tcpLayer != nil {
		tcp, _ = tcpLayer.(*layers.TCP)
	}

	// Check for errors
	if err := decoded.ErrorLayer(); err != nil {
		return fmt.Errorf("Error decoding some part of the packet:", err)
	}

	src := &srcNode{
		node{
			ip:   ip.SrcIP,
			port: tcp.SrcPort,
		},
	}

	dst := &dstNode{
		node{
			ip:   ip.DstIP,
			port: tcp.DstPort,
		},
	}

	srcKey := src.String()
	dstKey := dst.String()

	var srv *RawSocketServer
	var ok bool

	if tcp.ACK {
		// Looking up srvection.

		if srv, ok = fwdSockets[srcKey][dstKey]; !ok {
			return errors.New("Unknown srvection.")
		}

		if tcp.Ack == srv.seq && tcp.Seq == srv.ack {

			switch srv.step {
			case StatusServerSYNACK:
				srv.step = StatusEstablished

				srv.ack = tcp.Seq
				srv.seq = tcp.Ack

				go func() {
					if err := srv.reader(); err != nil {
						log.Printf("reader: %q", err)
					}
				}()

			case StatusEstablished:
				if srv.writeLock {
					srv.writeMu.Unlock()
					srv.writeLock = false
				}

				payloadLen := uint32(len(tcp.Payload))

				if payloadLen > 0 {
					if err := srv.replyACK(tcp.Seq, payloadLen); err != nil {
						return err
					}
					srv.w.Write(tcp.Payload)
				}

				if tcp.PSH {
					// Forward data to application.
					srv.w.Flush()
					srv.connOut.Write(srv.wb.Bytes())
					srv.wb.Reset()
				}

				if tcp.FIN {
					if err := srv.replyACK(tcp.Seq, 1); err != nil {
						return err
					}
					srv.step = StatusClosing

					if err := srv.replyFINACK(); err != nil {
						return err
					}
					srv.step = StatusWaitClose
				}
			case StatusWaitClose:
				fwdSockets[srcKey][dstKey] = nil
			default:
				panic("Unsupported status.")
			}
		} else {
			return fmt.Errorf("%s -> %s: Unexpected (Seq=%d, Ack=%d) expecting (Seq=%d, Ack=%d).", srcKey, dstKey, tcp.Seq, tcp.Ack, srv.ack, srv.seq)
		}

	} else if tcp.SYN && tcp.Ack == 0 {
		// Someone is starting a connection.
		if fwdSockets[srcKey] == nil {
			fwdSockets[srcKey] = make(map[string]*RawSocketServer)
		}

		connOut, err := t.dialer.Dial("tcp", dstKey)
		if err != nil {
			// TODO: Reply RST
			return err
		}

		fwdSockets[srcKey][dstKey] = &RawSocketServer{
			connOut:     connOut,
			src:         src,
			dst:         dst,
			window:      tcp.Window,
			wb:          bytes.NewBuffer(nil),
			relayPacket: relayPacket,
		}

		srv = fwdSockets[srcKey][dstKey]
		srv.w = bufio.NewWriter(srv.wb)

		if err := srv.replySYNACK(tcp.Seq); err != nil {
			return err
		}
	} else {
		return fmt.Errorf("Unknown status.")
	}

	return nil
}

func randomSeqNumber() uint32 {
	return rand.Uint32()
}

func (r *RawSocketServer) reader() error {
	// TODO: handle closing
	var n, m int
	var err error

	for {
		buf := make([]byte, 1024)
		if n, err = r.connOut.Read(buf); err != nil {
			if err != io.EOF {
				return err
			}
		}
		if n > 0 {
			if m, err = r.Write(buf[0:n]); err != nil {
				return err
			}
			if n != m {
				return fmt.Errorf("Failed to write some bytes to tun device.")
			}
		}
	}

	return nil
}
