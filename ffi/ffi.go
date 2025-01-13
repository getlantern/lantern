package main

import "C"
import (
	"context"
	"log"
	"sync"

	"github.com/getlantern/lantern-outline/dialer"
	"github.com/getlantern/lantern-outline/vpn"
)

const (
	mtu    = 1500
	offset = 0
)

var (
	vpnMutex sync.RWMutex
	server   vpn.VPNServer
)

//export startVPN
func startVPN() C.int {
	log.Print("startVPN called")
	ctx := context.Background()
	vpnMutex.Lock()
	defer vpnMutex.Unlock()
	if server != nil && server.IsVPNConnected() {
		return 1
	}
	dialer, err := dialer.NewShadowsocks("", "", "")
	if err != nil {
		return 1
	}
	server = vpn.NewVPNServer(dialer, "", mtu, offset)
	if err := start(ctx, server); err != nil {
		log.Printf("Unable to start VPN server: %v", err)
		return 1
	}
	return 0
}

//export stopVPN
func stopVPN() C.int {
	log.Print("stopVPN called")
	vpnMutex.Lock()
	defer vpnMutex.Unlock()
	if server != nil {
		if err := server.Stop(); err != nil {
			log.Printf("Unable to stop VPN server: %v", err)
			return 1
		}
		server = nil
	}
	return 0
}

//export isVPNConnected
func isVPNConnected() int {
	vpnMutex.RLock()
	defer vpnMutex.RUnlock()
	if server != nil && server.IsVPNConnected() {
		return 1
	}
	return 0
}

//export enforce_binding
func enforce_binding() {}

func main() {}
