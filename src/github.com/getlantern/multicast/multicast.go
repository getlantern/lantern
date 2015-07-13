// Use multicast to discover other processes on the same local network
// See RFC-5771 for IANA IPv4 Multicast address assignments
// See RFC-2365 for Administratively Scoped IP Multicast
// This implementation supports multicast failure detection, also disseminated
// via simple multicast.

package multicast

import (
	"net"
	"time"

	"github.com/getlantern/golog"
)

const (
	// Addresses for Administratively Scoped IP Multicast are in the space 239/8
	multicastIP       = "232.77.77.77"
	multicastPort     = "9864"
	multicastAddress  = multicastIP + ":" + multicastPort
	defaultPeriod     = 9
	defaultFailedTime = 30 // Seconds until a peer is considered failed
)

var (
	log = golog.LoggerFor("multicast")
)

type eventCallback func(string, []PeerInfo)

// Multicast servent main structure
type Multicast struct {
	Period  int    // multicast period (in secs, 10 by default)
	Payload string // Will be appended to the messages

	conn               *net.UDPConn
	addr               *net.UDPAddr
	failedTime         int           // timeout for peers' hello messages, 0 means no timeout
	addPeerCallback    eventCallback // Callback called when a peer is added (added, all)
	removePeerCallback eventCallback // Callback called when a peer is removed (removed, all)
	quit               chan bool
	helloTicker        *time.Ticker
	peers              map[string]PeerInfo
}

// PeerInfo holds the information about a detected peer
type PeerInfo struct {
	IP      net.IP
	Time    time.Time
	Payload string
}

// JoinMulticast joins the Lantern multicast group. Two callbacks must be provided:
// the first will be called when a new peer is added to the list and the second will
// be called when removed. A nil callback will be considered an empty function and just
// do nothing.
func JoinMulticast(addPeerCallback eventCallback, removePeerCallback eventCallback) *Multicast {
	udpAddr, e := net.ResolveUDPAddr("udp4", multicastAddress)
	if e != nil {
		log.Error(e)
		return nil
	}

	c, e := net.ListenMulticastUDP("udp4", nil, udpAddr)
	if e != nil {
		log.Error(e)
		return nil
	}

	// Make sure that we have sane callbacks in place, avoiding regular nil checks
	defaultCb := func(string, []PeerInfo) {}

	var aCb eventCallback
	if addPeerCallback != nil {
		aCb = addPeerCallback
	} else {
		aCb = defaultCb
	}

	var rCb eventCallback
	if removePeerCallback != nil {
		rCb = removePeerCallback
	} else {
		rCb = defaultCb
	}

	return &Multicast{
		Period:             defaultPeriod,
		conn:               c,
		addr:               udpAddr,
		failedTime:         defaultFailedTime,
		addPeerCallback:    aCb,
		removePeerCallback: rCb,
		quit:               make(chan bool, 1),
		peers:              make(map[string]PeerInfo),
	}
}

// StartMulticast initiates advertising ourselves through multicasting
func (mc *Multicast) StartMulticast() {
	// Periodically announce ourselves to the network
	go func() {
		if err := mc.sendHellos(); err != nil {
			log.Error(err)
		}
	}()
}

// ListenPeers listens peers in previously joined multicast group
func (mc *Multicast) ListenPeers() {
	// Listen multicasts by others
	go func() {
		if err := mc.listenPeers(); err != nil {
			log.Error(err)
		}
	}()
}

// LeaveMulticast stops multicasting and leaves the group. This should be called by the
// users of this library when the program exits or the discovery service is disabled by
// the end user
func (mc *Multicast) LeaveMulticast() {
	// Stop sending hello
	if mc.helloTicker != nil {
		mc.helloTicker.Stop()
	}
	msg, e := makeByeMessage(mc.Payload).serialize()
	if e != nil {
		log.Error(e)
	}

	if _, e = mc.write(msg); e != nil {
		log.Error(e)
	}

	// Leave the listening goroutine as soon as it timeouts
	mc.quit <- true
}

func (mc *Multicast) peersInfo() []PeerInfo {
	plist := make([]PeerInfo, len(mc.peers))
	i := 0
	for _, v := range mc.peers {
		plist[i] = v
		i++
	}
	return plist
}

func (mc *Multicast) write(b []byte) (int, error) {
	return mc.conn.WriteTo(b, mc.addr)
}

func (mc *Multicast) read(b []byte) (int, *net.UDPAddr, error) {
	return mc.conn.ReadFromUDP(b)
}

// sendHellos returns an error if failing to set up the message, otherwise it handles its own
// errors (i.e. it will keep sending hellos after a failure).
func (mc *Multicast) sendHellos() error {
	mc.helloTicker = time.NewTicker(time.Duration(mc.Period) * time.Second)
	msg, e := makeHelloMessage(mc.Payload).serialize()
	if e != nil {
		return e
	}
	for range mc.helloTicker.C {
		if _, e = mc.write(msg); e != nil {
			log.Error(e)
		}
	}
	return nil
}

// listenPeers returns an error if failing to quit listening, otherwise and just as
// sendHellos it handles its own internal errors and keeps working.
func (mc *Multicast) listenPeers() error {
	b := make([]byte, messageMaxSize)
	for {
		select {
		case <-mc.quit:
			return mc.conn.Close()
		default:
			// We are checking first that no peer has failed. If we don't
			// hear from peers soon enough, we consider them failed.
			for p, pinfo := range mc.peers {
				// FailedTime zero means no timeout
				if time.Now().After(pinfo.Time) && mc.failedTime != 0 {
					delete(mc.peers, p)
					mc.removePeerCallback(p, mc.peersInfo())
				}
			}

			// Set a deadline to avoid blocking on a read forever
			e := mc.conn.SetReadDeadline(time.Now().Add(time.Duration(mc.Period) * time.Second))
			if e != nil {
				log.Error(e)
			}
			n, udpAddr, e := mc.read(b)
			if e != nil {
				// Just start over if any error happened when reading
				break
			}
			udpAddrStr := udpAddr.String()

			msg := b[:n]
			mcMsg, e := deserialize(msg)
			if e != nil {
				log.Error(e)
				break
			}
			switch mcMsg.Type {
			case typeHello:
				// Test whether I'm the origin of this multicast
				if isFromMe(udpAddr.IP) {
					break
				}

				// Add/Update peer
				_, ok := mc.peers[udpAddrStr]

				// A time in the future when that, if no hello message from the peer is
				// received, it will be considered failed. Update every time.
				mc.peers[udpAddrStr] = PeerInfo{
					IP:      udpAddr.IP,
					Time:    time.Now().Add(time.Second * time.Duration(mc.failedTime)),
					Payload: mcMsg.Payload,
				}

				if !ok {
					mc.addPeerCallback(udpAddrStr, mc.peersInfo())
				}
			case typeBye:
				_, ok := mc.peers[udpAddrStr]
				// Remove peer
				if ok {
					delete(mc.peers, udpAddrStr)
					mc.removePeerCallback(udpAddrStr, mc.peersInfo())
				}
			default:
				log.Error("Unrecognized message sent to Lantern multicast address")
			}
		}
	}
}

func isFromMe(ip net.IP) bool {
	addrs, e := net.InterfaceAddrs()
	if e != nil {
		log.Error(e)
	}
	for _, a := range addrs {
		if ipnet, ok := a.(*net.IPNet); ok {
			if ip.Equal(ipnet.IP) {
				return true
			}
		}
	}
	return false
}
