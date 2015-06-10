// Use SSM multicast to discover other processes on the same local network
// See RFC-3569 for SSM description
// See RFC-5771 for IANA IPv4 Multicast address assignments
// This implementation supports multicast failure detection, also disseminated
// via simple multicast.

package multicast

import (
	"log"
	"net"
	"os"
	"strings"
	"time"
)

const (
	// Addresses for SSM multicasting are in the space 232/8
	// See https://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml#multicast-addresses-10
	multicastIP = "232.77.77.77"
	multicastPort = "9864"
	multicastAddress = multicastIP + ":" + multicastPort
	maxUDPMsg = 1 << 12
	defaultPeriod = 10
	defaultFailedTime = 60 // Seconds until a peer is considered failed

	helloMsgPrefix = "Lantern Hello"
	byeMsgPrefix = "Lantern Bye"
)

type Multicast struct {
        Conn                 *net.UDPConn
        Addr                 *net.UDPAddr
	Period               int // multicast period (in secs, 10 by default)
	FailedTime           int // timeout for peers' hello messages, 0 means no timeout
	AddPeerCallback      func(string) // Callback called when a peer is added
	RemovePeerCallback   func(string) // Callback called when a peer is removed

	quit                 chan bool
	helloTicker          *time.Ticker
	peers                map [string]time.Time
}

// Join the Lantern multicast group
func JoinMulticast() *Multicast {
        udpAddr, e := net.ResolveUDPAddr("udp4", multicastAddress)
        if e != nil {
		log.Fatal(e)
                return nil
        }

        c, e := net.ListenMulticastUDP("udp4", nil, udpAddr)
        if e != nil {
                return nil
        }
        return &Multicast{
		Conn: c,
		Addr: udpAddr,
		Period: defaultPeriod,
		FailedTime: defaultFailedTime,
		quit: make(chan bool, 1),
		peers: make(map[string]time.Time),
	}
}

// Initiate multicasting
func (mc *Multicast) StartMulticast() {
	// Periodically announce ourselves to the network
	go mc.sendHellos()

	// Listen multicasts by others
	go mc.listenPeers()
}

// Stop multicasting and leave the group. This should be called by the users of
// this library when the program exits or the discovery service is disabled by
// the end user
func (mc *Multicast) LeaveMulticast() error {
	// Stop sending hello
	if mc.helloTicker != nil {
		mc.helloTicker.Stop()
	}
	// Send bye
	host, _ := os.Hostname()
	addrs, _ := net.LookupIP(host)
	mc.write( byeMessage(addrs) )

	// Leave the listening goroutine as soon as it timeouts
	mc.quit <- true

	return nil
}

func (mc *Multicast) write(b []byte) (int, error) {
        return mc.Conn.WriteTo(b, mc.Addr)
}

func (mc *Multicast) read(b []byte) (int, *net.UDPAddr, error) {
        return mc.Conn.ReadFromUDP(b)
}

func (mc *Multicast) sendHellos () {
	mc.helloTicker = time.NewTicker(time.Duration(mc.Period) * time.Second)
	for range mc.helloTicker.C {
		host, _ := os.Hostname()
		addrs, _ := net.LookupIP(host)
		mc.write( helloMessage(addrs) )
	}
}

func (mc *Multicast) listenPeers() error {
	b := make([]byte, maxUDPMsg)
	// Set a deadline to avoid blocking on a read forever
	for {
		select {
		case <- mc.quit:
			return mc.Conn.Close()
		default:
			mc.Conn.SetReadDeadline(time.Now().Add(time.Duration(mc.Period) * time.Second))
			n, udpAddr, e := mc.read(b)
			udpAddrStr := udpAddr.String()
			if e != nil {
				// Just start over if any error happened when reading
				break
			}

			msg := b[:n]
			if n > 0 {
				if isHello(msg) {
					// Add/Update peer only if its reported IP is the same as the
					// origin IP of the UDP package
					for _, a := range extractMessageAddresses(msg) {
						astr := a.String()
						if udpAddrStr == astr && !isMyIP(strings.TrimSuffix(astr, ":" + multicastPort)) {
							_, ok := mc.peers[udpAddrStr]
							if !ok && mc.AddPeerCallback != nil {
								mc.AddPeerCallback(udpAddrStr)
							}
							// A time in the future when that, if no hello message from the peer is
							// received, it will be considered failed. Update every time.
							mc.peers[udpAddrStr] = time.Now().Add(time.Second * time.Duration(mc.FailedTime))
						}
					}
				} else if isBye(msg) {
					_, ok := mc.peers[udpAddrStr]
					if !ok {
						// Remove peer
						if mc.RemovePeerCallback != nil {
							mc.RemovePeerCallback(udpAddrStr)
						}
						delete(mc.peers, udpAddrStr)
					}
				} else {
					log.Fatal("Unrecognized message sent to Lantern multicast SSM address")
				}
			}

			// We are checking here also that no peer is too old. If we don't
			// hear from peers soon enough, we consider them failed.
			for p, pt := range mc.peers {
				// FailedTime zero means no timeout
				if time.Now().After(pt) && mc.FailedTime != 0 {
					delete(mc.peers, p)
				}
			}
		}
	}
}

func helloMessage(addrs []net.IP) []byte {
	return []byte(helloMsgPrefix + IPsToString(addrs))
}

func byeMessage(addrs []net.IP) []byte {
	return []byte(byeMsgPrefix + IPsToString(addrs))
}

func IPsToString(addrs []net.IP) string {
	var msg string
	for _, addr := range addrs {
		if ipv4 := addr.To4(); ipv4 != nil {
			msg += "|" + ipv4.String() + ":" + multicastPort
		}
	}
	return msg
}

func isHello(msg []byte) bool {
	return strings.HasPrefix(string(msg), helloMsgPrefix)
}

func isBye(msg []byte) bool {
	return strings.HasPrefix(string(msg), byeMsgPrefix)
}

func extractMessageAddresses(msg []byte) []*net.UDPAddr {
	strMsg := string(msg)
	strMsg = strings.TrimPrefix(strMsg, helloMsgPrefix)
	strs := strings.Split(strMsg[1:], "|")
	addrs := make([]*net.UDPAddr, len(strs))

	for i, str := range strs {
		addr, e := net.ResolveUDPAddr("udp4",str)
		if e != nil {
			continue
		}
		addrs[i] = addr
	}
	return addrs
}

func isMyIP(addr string) bool {
	host, _ := os.Hostname()
	addrs, _ := net.LookupIP(host)
	for _, a := range addrs {
		if addr == a.String() {
			return true
		}
	}
	return false
}
