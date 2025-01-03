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
	"unsafe"

	"github.com/getlantern/lantern-outline/dialer"
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

func startTun2SocksImpl() error {
	ssDialer, err := dialer.NewShadowsocks("192.168.0.253:8388", "aes-256-gcm", "mytestpassword")
	if err != nil {
		return err
	}
	return server.RunTun2Socks(processOutboundPacket, ssDialer)
}
