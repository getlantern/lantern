package main

//
// #cgo CFLAGS: -I./ffi
// #include <stdlib.h>
// extern void SwiftLog(const char* message);
// extern int WriteToOS(const void *packetPtr, int length);
// extern int ExcludeRouteFromOS(const char *route);
//
import "C"
import (
	"context"
	"unsafe"

	"github.com/getlantern/lantern-outline/vpn"
)

// IOS-related

type iosBridge struct{}

// ProcessOutboundPacket sends an outbound packet from Go to Swift for processing by the OS.
func (*iosBridge) ProcessOutboundPacket(pkt []byte) bool {
	if len(pkt) == 0 {
		return false
	}
	logToSwift("Process outbound packet")
	cPacketPtr := unsafe.Pointer(&pkt[0])
	cLength := C.int(len(pkt))
	result := C.WriteToOS(cPacketPtr, cLength)
	return result == 1
}

// ExcludeRoute dynamically excludes a route in Swift networking layer.
func (*iosBridge) ExcludeRoute(route string) bool {
	cRoute := C.CString(route)
	defer C.free(unsafe.Pointer(cRoute))

	result := C.ExcludeRouteFromOS(cRoute)
	if result == 1 {
		log.Debugf("excludeRoute: Successfully excluded route %s", route)
		return true
	}
	log.Debugf("excludeRoute: Failed to exclude route %s", route)
	return false
}

// Helper function to send logs to Swift
func logToSwift(message string) {
	cMessage := C.CString(message)
	defer C.free(unsafe.Pointer(cMessage))
	C.SwiftLog(cMessage)
}

// start initializes the VPN server and starts the Tun2Socks process.
func start(ctx context.Context, server vpn.VPNServer) error {
	if err := server.StartTun2Socks(ctx, &iosBridge{}); err != nil {
		return err
	}
	return nil
}

// ProcessInboundPacket is called by Swift when a packet arrives from the OS.
//
//export ProcessInboundPacket
func ProcessInboundPacket(packetPtr unsafe.Pointer, packetLen C.int) {
	//logToSwift("Received inbound packet")
	if isVPNConnected() == 1 {
		raw := C.GoBytes(packetPtr, packetLen)
		server.ProcessInboundPacket(raw, int(packetLen))
	}
}
