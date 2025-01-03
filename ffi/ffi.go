package main

//
// #cgo CFLAGS: -I./ffi
// #include <stdlib.h>
// extern void SwiftLog(const char* message);
// extern int WriteToOS(const void *packetPtr, int length);
//
import "C"
import (
	"log"
	"sync"
	"unsafe"

	"github.com/getlantern/lantern-outline/dialer"
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

//export StartTun2Socks
func StartTun2Socks() C.int {
	err := startTun2SocksImpl()
	if err != nil {
		return 1 // or some other nonzero code
	}
	return 0
}

//export ProcessInboundPacket
func ProcessInboundPacket(packetPtr unsafe.Pointer, packetLen C.int) {
	//logToSwift("Received inbound packet")
	raw := C.GoBytes(packetPtr, packetLen)
	server.ProcessInboundPacket(raw, int(packetLen))
}

//export enforce_binding
func enforce_binding() {}

// IOS-related

// Helper function to send logs to Swift
func logToSwift(message string) {
	cMessage := C.CString(message)
	defer C.free(unsafe.Pointer(cMessage))
	C.SwiftLog(cMessage)
}

func sendPacketToOS(pkt []byte) bool {
	if len(pkt) == 0 {
		return false
	}
	logToSwift("Process outbound packet")
	cPacketPtr := unsafe.Pointer(&pkt[0])
	cLength := C.int(len(pkt))
	result := C.WriteToOS(cPacketPtr, cLength)
	if result == 1 {
		log.Printf("sendPacketToOS: Packet sent successfully")
	} else {
		log.Printf("sendPacketToOS: Failed to send packet")
	}
	return result == 1
}

func startTun2SocksImpl() error {
	ssDialer, err := dialer.NewShadowsocks("192.168.0.253:8388", "aes-256-gcm", "mytestpassword")
	if err != nil {
		return err
	}
	return server.RunTun2Socks(sendPacketToOS, ssDialer)
}

func main() {}
