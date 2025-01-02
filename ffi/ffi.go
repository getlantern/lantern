package main

//
// #cgo CFLAGS: -I./ffi
// #include <stdlib.h>
//
import "C"
import (
	"log"
	"sync"
	"time"

	"github.com/getlantern/lantern-outline/vpn"
)

var (
	tunnelMu sync.RWMutex
	tunnel   vpn.Tunnel
)

func init() {
	tunnel, _ = vpn.NewTunnel(false, 30*time.Second)
}

//export startVPN
func startVPN() {
	log.Print("startVPN called")
	tunnelMu.Lock()
	defer tunnelMu.Unlock()
	tunnel.Start()
}

//export stopVPN
func stopVPN() {
	log.Print("stopVPN called")
	tunnelMu.Lock()
	defer tunnelMu.Unlock()
	tunnel.Stop()
}

//export isVPNConnected
func isVPNConnected() int {
	tunnelMu.RLock()
	defer tunnelMu.RUnlock()
	if tunnel.IsConnected() {
		return 1
	}
	return 0
}

//export StartTun2Socks
func StartTun2Socks() C.int {
	err := startTun2SocksImpl()
	if err != nil {
		return 1 // or some other nonzero code
	}
	return 0
}

//export enforce_binding
func enforce_binding() {}

func main() {}
