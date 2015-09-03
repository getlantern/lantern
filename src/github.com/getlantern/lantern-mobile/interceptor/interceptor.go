// package interceptor which intercepts and forwards traffic between
// a VPN tun interface (typically established via Android VpnService)
// and Lantern
package interceptor

// #cgo LDFLAGS: -I/usr/include

import (
	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-mobile/protected"
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
	httpAddr  string
	socksAddr string

	// whether or not to print all incoming packets
	logPackets bool
}

func New(protector protected.SocketProtector, logPackets bool,
	httpAddr string,
	socksAddr string,
	writePacket func([]byte), isMasquerade func(string) bool) *Interceptor {
	i := &Interceptor{
		protector:    protector,
		httpAddr:     httpAddr,
		socksAddr:    socksAddr,
		logPackets:   logPackets,
		writePacket:  writePacket,
		isMasquerade: isMasquerade,
	}

	_, err := NewSocksProxy(i)
	if err != nil {
		log.Errorf("Error starting SOCKS proxy: %v", err)
		return nil
	}

	log.Debugf("Configured interceptor; Ready to consume packets!")
	return i
}
