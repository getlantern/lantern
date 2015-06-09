// Use SSM multicast to discover other processes on the same local network
// See RFC-3569 for SSM description
// See RFC-5771 for IANA IPv4 Multicast address assignments

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

	helloMsgPrefix = "Lantern Hello"
	byeMsgPrefix = "Lantern Bye"
)

type Multicast struct {
        Conn        *net.UDPConn
        Addr        *net.UDPAddr
	Period      int // multicast period (in secs, 10 by default)

	active      bool
	helloTicker *time.Ticker
	peers       map [string]bool
}

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
		Period: 10,
		active: false,
		helloTicker: nil,
		peers: make(map[string]bool),
	}
}

func (mc *Multicast) StartMulticast() {
	// Periodically announce ourselves to the network
	go mc.sendHellos()

	// Listen multicasts by others
	go mc.listenPeers()

	mc.active = true
}

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
	mc.active = false

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
	// Set a deadline to avoid blocking a read for ever
	for mc.active {
		mc.Conn.SetReadDeadline(time.Now().Add(time.Duration(mc.Period) * time.Second))
		n, udpAddr, e := mc.read(b)
		udpAddrStr := udpAddr.String()
		if e != nil {
			log.Println(e)
			mc.active = false
		}

		msg := b[:n]
		if n > 0 {
			if isHello(msg) {
				// Add peer only if its reported IP is the same as the
				// origin IP of the UDP package
				for _, a := range extractMessageAddresses(msg) {
					if udpAddrStr == a.String() {
						mc.peers[udpAddrStr] = true
					}
				}
			} else if isBye(msg) {
				// Remove peer
				delete(mc.peers, udpAddrStr)
			} else {
				log.Fatal("Unrecognized message sent to Lantern multicast SSM address")
			}
		}
	}
	return mc.Conn.Close()
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
