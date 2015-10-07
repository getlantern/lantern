package main

import (
	"bufio"
	"errors"
	"flag"
	"github.com/getlantern/tunio"
	"log"
	"net"
	"net/http"
)

var (
	deviceName = flag.String("tundev", "tun0", "TUN device name.")
	deviceIP   = flag.String("netif-ipaddr", "", "Address of the virtual router inside the TUN device.")
	deviceMask = flag.String("netif-netmask", "", "Network mask that defines the traffic that is going to be redirected to the TUN device.")
	proxyAddr  = flag.String("proxy-addr", "", "Lantern address.")
)

var DefaultDialer = LanternDialer

func LanternDialer(proto, addr string) (net.Conn, error) {
	conn, err := net.Dial("tcp", *proxyAddr)

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
		log.Printf("Proxying %q to Lantern...", addr)
		return conn, nil
	}

	log.Printf("Could not reach Lantern.")

	return nil, errors.New("Could not connect.")
}

func main() {
	flag.Parse()

	log.Printf("Configuring device %q (ipaddr: %q, netmask: %q)", *deviceName, *deviceIP, *deviceMask)
	if err := tunio.Configure(*deviceName, *deviceIP, *deviceMask, DefaultDialer); err != nil {
		log.Fatalf("Failed to configure device: %q", err)
	}
}
