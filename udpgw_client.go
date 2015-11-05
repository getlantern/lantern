package tunio

import (
	"log"
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
	connID      uint16
	conn        net.Conn
	cLocalAddr  C.BAddr
	cRemoteAddr C.BAddr
}

//export goUdpGwClient_GetLocalAddrByConnId
func goUdpGwClient_GetLocalAddrByConnId(cConnID C.uint16_t) C.BAddr {
	conn := udpgwGetConnById(uint16(cConnID))
	return conn.cLocalAddr
}

func DialUDP() (net.Conn, error) {
	conn, err := net.Dial("tcp", "10.4.4.120:5353")
	if err != nil {
		return nil, err
	}
	go func() {
		for {
			head := make([]byte, 2)
			n, err := conn.Read(head)
			if err != nil {
				return
			}
			if n > 0 {
				size := 0
				size += int(head[0])
				size += int(head[1]) << 8

				data := make([]byte, size)
				n, err := conn.Read(data)
				if err != nil {
					return
				}

				if n != size {
					panic("dont know how to handle this.")
				}

				cchunk := C.CString(string(data))
				C.udpGWClient_ReceiveFromServer(cchunk, C.int(len(data)))
			}
		}
	}()
	return conn, nil
}

var (
	udpgwConnMap map[string]map[string]uint16
	udpgwConn    map[uint16]*udpGwClient
	udpgwConnMu  sync.Mutex
)

func udpgwGetConnById(connId uint16) *udpGwClient {
	return udpgwConn[connId]
}

// udpgwGetConn returns or creates a connection and returns the connection ID.
func udpgwGetConn(localAddr, remoteAddr string) (uint16, error) {

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
			connId = uint16(rand.Int31() % (1 << 16))
			if _, ok := udpgwConn[connId]; !ok {
				udpgwConn[connId] = client
				break
			}
		}
		udpgwConnMu.Unlock()

		if udpgwConnMap[localAddr] == nil {
			udpgwConnMap[localAddr] = make(map[string]uint16)
		}

		udpgwConnMap[localAddr][remoteAddr] = connId
	}

	return connId, nil
}

//export goUdpGwClient_Send
// goUdpGwClient_Send sends a packet to the udpgw server.
func goUdpGwClient_Send(connId uint16, data *C.uint8_t, dataLen C.int) C.int {
	c := udpgwGetConnById(connId)

	size := int(dataLen)

	if size >= (1 << 16) {
		panic("Packet is too large.")
	}

	buf := make([]byte, 2+size)

	// First two bytes for packet length. Low byte first.
	buf[0] = byte(size % (1 << 8))
	buf[1] = byte(size / (1 << 8))

	// Then the packet.
	for i := 0; i < size; i++ {
		buf[i+2] = byte(C.dataAt(data, C.int(i)))
	}

	// Sending packet to udpgw server.
	_, err := c.conn.Write(buf)
	if err != nil {
		log.Printf("conn.Write: %q\n", err)
		return C.ERR_ABRT
	}

	return C.ERR_OK
}

//export goUdpGwClient_FindConnectionByAddr
// goUdpGwClient_FindConnectionByAddr returns a connection ID given local and
// remote addresses.
func goUdpGwClient_FindConnectionByAddr(cLocalAddr C.BAddr, cRemoteAddr C.BAddr) C.uint16_t {
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
		return 0
	}

	client := udpgwGetConnById(connId)
	client.cLocalAddr = cLocalAddr
	client.cRemoteAddr = cRemoteAddr

	return C.uint16_t(connId)
}
