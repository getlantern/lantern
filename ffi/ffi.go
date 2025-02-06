package main

import "C"
import (
	"context"
	"log"
	"sync"

	"github.com/getlantern/lantern-outline/vpn"
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
	var err error
	server, err = vpn.NewVPNServer(&vpn.Opts{Address: ":0"})
	if err != nil {
		log.Printf("Unable to create VPN server: %v", err)
		return 1
	}
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
