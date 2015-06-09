// Use SSM multicast to discover other processes on the same local network
// See RFC-3569 for SSM description
// See RFC-5771 for IANA IPv4 Multicast address assignments

package multicast

import (
	"log"
	"net"
	"os"
	"time"
)

const (
	// Addresses for SSM multicasting are in the space 232/8
	// See https://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml#multicast-addresses-10
	multicastAddress = "232.77.77.77:9864"
)

type Multicast struct {
        Conn        *net.UDPConn
        Addr        *net.UDPAddr
	Period      int // multicast period (in secs, 10 by default)
}

func JoinMulticast() (*Multicast) {
        udpAddr, e := net.ResolveUDPAddr("udp4", multicastAddress)
        if e != nil {
		log.Fatal(e)
                return nil
        }

        c, e := net.ListenMulticastUDP("udp4", nil, udpAddr)
        if e != nil {
                return nil
        }
        return &Multicast{c, udpAddr, 10}
}

func (mc *Multicast) StartMulticast() {
	// Periodically announce ourselves to the network
	go mc.sendHellos()
}

func (mc *Multicast) LeaveMulticast() error {
        return mc.Conn.Close()
}

func (mc *Multicast) write(b []byte) (int, error) {
        return mc.Conn.WriteTo(b, mc.Addr)
}

func (mc *Multicast) read(b []byte) (int, error) {
        return mc.Conn.Read(b)
}

func (mc *Multicast) sendHellos () {
	c := time.Tick(time.Duration(mc.Period) * time.Second)
	for range c {
		host, _ := os.Hostname()
		addrs, _ := net.LookupIP(host)
		mc.write( helloMessage(addrs) )
	}
}

func helloMessage(addrs []net.IP) []byte {
	return []byte("Hello:" + addressesToString(addrs))
}

func byeMessage(addrs []net.IP) []byte {
	return []byte("Bye:" + addressesToString(addrs))
}

func addressesToString(addrs []net.IP) string {
	var msg string
	for _, addr := range addrs {
		if ipv4 := addr.To4(); ipv4 != nil {
			msg += " "
			msg += ipv4.String()
			msg += " |"
		}
	}
	return msg
}
