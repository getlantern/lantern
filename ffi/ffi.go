package main

import "C"
import (
	"context"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/vpn"
)

var (
	vpnMutex sync.RWMutex
	server   vpn.VPNServer

	log = golog.LoggerFor("lantern-outline.ffi")
)

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() C.int {
	log.Debug("startVPN called")

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	if server == nil {
		var err error
		server, err = vpn.NewVPNServer(&vpn.Opts{Address: ":0"})
		if err != nil {
			log.Debugf("Unable to create VPN server: %v", err)
			return 1
		}
	}
	if err := start(context.Background(), server); err != nil {
		log.Debugf("Unable to start VPN server: %v", err)
		return 1
	}
	log.Debug("VPN server started successfully")
	return 0
}

// stopVPN stops the VPN server if it is running.
//
//export stopVPN
func stopVPN() C.int {
	log.Debug("stopVPN called")

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	if server == nil {
		log.Debug("VPN server is not running")
		return 0
	}

	if err := server.Stop(); err != nil {
		log.Debugf("Unable to stop VPN server: %v", err)
		return 1
	}

	return 0
}

// isVPNConnected checks if the VPN server is running and connected.
//
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
