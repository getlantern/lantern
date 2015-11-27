package main

import (
	"flag"
	"github.com/getlantern/tunio"
	"log"
)

var (
	deviceName = flag.String("tundev", "tun0", "TUN device name.")
	deviceIP   = flag.String("netif-ipaddr", "", "Address of the virtual router inside the TUN device.")
	deviceMask = flag.String("netif-netmask", "", "Network mask that defines the traffic that is going to be redirected to the TUN device.")
	proxyAddr  = flag.String("proxy-addr", "", "Lantern address.")
	udpgwAddr  = flag.String("udpgw-remote-server-addr", "", "UDPGW remote server address (optional).")
)

func main() {
	flag.Parse()

	dialer := tunio.NewLanternDialer(*proxyAddr)

	log.Printf("Configuring device %q (ipaddr: %q, netmask: %q)", *deviceName, *deviceIP, *deviceMask)
	if err := tunio.ConfigureTUN(*deviceName, *deviceIP, *deviceMask, *udpgwAddr, dialer); err != nil {
		log.Fatalf("Failed to configure device: %q", err)
	}
}
