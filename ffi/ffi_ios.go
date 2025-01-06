package main

//
// #cgo CFLAGS: -I./ffi
// #include <stdlib.h>
// extern void SwiftLog(const char* message);
// extern int WriteToOS(const void *packetPtr, int length);
//
import "C"
import (
	"context"
	"log"
	"unsafe"

	"github.com/getlantern/lantern-outline/vpn"
)

// IOS-related

// Helper function to send logs to Swift
func logToSwift(message string) {
	cMessage := C.CString(message)
	defer C.free(unsafe.Pointer(cMessage))
	C.SwiftLog(cMessage)
}

func processOutboundPacket(pkt []byte) bool {
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

func start(ctx context.Context, server vpn.VPNServer) error {
	if err := server.StartTun2Socks(ctx, processOutboundPacket); err != nil {
		return err
	}
	return nil
}

//export ProcessInboundPacket
func ProcessInboundPacket(packetPtr unsafe.Pointer, packetLen C.int) {
	//logToSwift("Received inbound packet")
	if isVPNConnected() == 1 {
		raw := C.GoBytes(packetPtr, packetLen)
		server.ProcessInboundPacket(raw, int(packetLen))
	}
}
