package main

import "C"
import (
	"log"
	"sync"

	"github.com/getlantern/lantern-outline/vpn"
)

var (
	vpnMutex sync.RWMutex
	server   vpn.VPNServer
)

func init() {
	const (
		mtu    = 1500
		offset = 0
	)
	server = vpn.NewVPNServer("", mtu, offset)
}

//export startVPN
func startVPN() {
	log.Print("startVPN called")
	// tunnelMu.Lock()
	// defer tunnelMu.Unlock()
	// tunnel.Start()
}

//export stopVPN
func stopVPN() {
	log.Print("stopVPN called")
	// tunnelMu.Lock()
	// defer tunnelMu.Unlock()
	// tunnel.Stop()
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
