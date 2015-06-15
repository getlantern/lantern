// Use multicast to discover other processes on the same local network
// See RFC-5771 for IANA IPv4 Multicast address assignments
// See RFC-2365 for Administratively Scoped IP Multicast
// This implementation supports multicast failure detection, also disseminated
// via simple multicast.

package multicast

import (
	"log"
	"net"
	"time"
)

const (
	// Addresses for Administratively Scoped IP Multicast are in the space 239/8
	multicastIP = "239.77.77.77"
	multicastPort = "9864"
	multicastAddress = multicastIP + ":" + multicastPort
	defaultPeriod = 10
	defaultFailedTime = 60 // Seconds until a peer is considered failed
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
	msg, e := MakeByeMessage().Serialize()
	if e != nil {
		log.Fatal(e)
	}
	mc.write(msg)

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

func (mc *Multicast) sendHellos() {
	mc.helloTicker = time.NewTicker(time.Duration(mc.Period) * time.Second)
	msg, e := MakeHelloMessage().Serialize()
	if e != nil {
		log.Fatal(e)
		return
	}
	for range mc.helloTicker.C {
		mc.write(msg)
	}
}

func (mc *Multicast) listenPeers() error {
	b := make([]byte, messageMaxSize)
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
			mcMsg, e := Deserialize(msg)
			if e != nil {
				break
			}
			switch mcMsg.mType {
			case TypeHello:
				// Test whether I'm the origin of this multicast
				otherPeer := true
				for _, ip := range getMyIPs() {
					if ip.Equal(udpAddr.IP) {
						otherPeer = false
						break
					}
				}
				if otherPeer {
					// Add/Update peer
					_, ok := mc.peers[udpAddrStr]
					if !ok && mc.AddPeerCallback != nil {
						mc.AddPeerCallback(udpAddrStr)
					}
					// A time in the future when that, if no hello message from the peer is
					// received, it will be considered failed. Update every time.
					mc.peers[udpAddrStr] = time.Now().Add(time.Second * time.Duration(mc.FailedTime))
				}
			case TypeBye:
				_, ok := mc.peers[udpAddrStr]
				if ok {
					// Remove peer
					if mc.RemovePeerCallback != nil {
						mc.RemovePeerCallback(udpAddrStr)
					}
					delete(mc.peers, udpAddrStr)
				}
			default:
				log.Fatal("Unrecognized message sent to Lantern multicast SSM address")
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

func getMyIPs() (ips []net.IP) {
	addrs, e := net.InterfaceAddrs()
	if e != nil {
		log.Fatal (e)
		return
	}
	for _, a := range addrs {
		if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			ips = append(ips, ipnet.IP)
		}
	}
	return
}
