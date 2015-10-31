package tunio

import (
	"math/rand"
	"net"
	"sync"
	"unsafe"
)

/*
#include "tun2io.h"
#include "tun2io.c"
*/
import "C"

type udpGwClient struct {
	connID int
	conn   net.Conn
}

func DialUDP() (net.Conn, error) {
	conn, err := net.Dial("tcp", "10.4.4.120:5353")
	if err != nil {
		return nil, err
	}
	return conn, nil
}

var (
	udpgwConnMap map[string]map[string]uint32
	udpgwConn    map[uint32]*udpGwClient
	udpgwConnMu  sync.Mutex
)

func udpgwGetConn(localAddr, remoteAddr string) (uint32, error) {

	connId, ok := udpgwConnMap[localAddr][remoteAddr]

	if !ok {
		conn, err := DialUDP()

		if err != nil {
			return 0, err
		}

		client := &udpGwClient{
			conn: conn,
		}

		// Get ID
		udpgwConnMu.Lock()
		for {
			connId = uint32(rand.Int31())
			if _, ok := udpgwConn[connId]; !ok {
				udpgwConn[connId] = client
				break
			}
		}
		udpgwConnMu.Unlock()

		udpgwConnMap[localAddr][remoteAddr] = connId
	}

	return connId, nil
}

func goUdpGwSend(connId uint32, data *C.uint8_t, dataLen C.int) C.int {
	return 0
}

//export goUdpGwClient_SubmitPacket
func goUdpGwClient_SubmitPacket(cLocalAddr C.BAddr, cRemoteAddr C.BAddr, cIsDNS C.int, cData *C.uint8_t, cDataLen C.int) C.int {
	// Open a connection for localAddr and remoteAddr
	laddr := C.baddr_to_str(&cLocalAddr)
	raddr := C.baddr_to_str(&cRemoteAddr)

	defer func() {
		C.free(unsafe.Pointer(laddr))
		C.free(unsafe.Pointer(raddr))
	}()

	localAddr := C.GoString(laddr)
	remoteAddr := C.GoString(raddr)

	connId, err := udpgwGetConn(localAddr, remoteAddr)
	if err != nil {
		return -1
	}

	return C.int(connId)
}
