package main

import (
	"bufio"
	"errors"
	"flag"
	"github.com/getlantern/tunio"
	"log"
	"net"
	"net/http"
	"time"
)

var (
	deviceName = flag.String("tundev", "tun0", "TUN device name.")
	deviceIP   = flag.String("netif-ipaddr", "", "Address of the virtual router inside the TUN device.")
	deviceMask = flag.String("netif-netmask", "", "Network mask that defines the traffic that is going to be redirected to the TUN device.")
	proxyAddr  = flag.String("proxy-addr", "", "Lantern address.")
	udpgwAddr  = flag.String("udpgw-remote-server-addr", "", "UDPGW remote server address (optional).")
)

var (
	timeout   = time.Second * 120
	keepAlive = time.Second * 120
)

func LanternDialer(proto, addr string) (net.Conn, error) {
	d := net.Dialer{
		Timeout:   timeout,
		KeepAlive: keepAlive,
	}

	conn, err := d.Dial("tcp", *proxyAddr)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("CONNECT", addr, nil)
	if err != nil {
		return nil, err
	}

	req.Host = addr
	if err := req.Write(conn); err != nil {
		return nil, err
	}

	r := bufio.NewReader(conn)
	resp, err := http.ReadResponse(r, req)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode >= 200 && resp.StatusCode <= 299 {
		log.Printf("Dialing %q through Lantern...", addr)
		return conn, nil
	}

	log.Printf("Status code %v.", resp.StatusCode)

	return nil, errors.New("Could not connect to Lantern.")
}

func main() {
	flag.Parse()

	log.Printf("Configuring device %q (ipaddr: %q, netmask: %q)", *deviceName, *deviceIP, *deviceMask)
	if err := tunio.Configure(*deviceName, *deviceIP, *deviceMask, *udpgwAddr, LanternDialer); err != nil {
		log.Fatalf("Failed to configure device: %q", err)
	}
}
