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
	connID int
	conn   net.Conn
}

func DialUDP() (net.Conn, error) {
	conn, err := net.Dial("tcp", "10.4.4.120:5353")
	if err != nil {
		return nil, err
	}
	go func() {
		for {
			buf := make([]byte, 10)
			n, err := conn.Read(buf)
			log.Printf("got read: %d, %q", n, err)
			log.Printf("data: %v\n", buf)
			if err != nil {
				return
			}
		}
	}()
	return conn, nil
}

var (
	udpgwConnMap map[string]map[string]uint32
	udpgwConn    map[uint32]*udpGwClient
	udpgwConnMu  sync.Mutex
)

func udpgwGetConnById(connId uint32) *udpGwClient {
	return udpgwConn[connId]
}

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
			connId = uint32(rand.Int31()%256 + 1)
			if _, ok := udpgwConn[connId]; !ok {
				udpgwConn[connId] = client
				break
			}
		}
		udpgwConnMu.Unlock()

		if udpgwConnMap[localAddr] == nil {
			udpgwConnMap[localAddr] = make(map[string]uint32)
		}

		udpgwConnMap[localAddr][remoteAddr] = connId
	}

	return connId, nil
}

//export goUdpGwClient_Send
func goUdpGwClient_Send(connId uint32, flags C.uint8_t, data *C.uint8_t, dataLen C.int) C.int {
	c := udpgwGetConnById(connId)

	bl := int(dataLen)
	buf := make([]byte, bl)

	for i := 0; i < bl; i++ {
		buf[i] = byte(C.dataAt(data, C.int(i)))
	}

	buf2 := make([]byte, 0, bl+2)
	buf2 = append([]byte{0x25, 0x00}, buf...)

	log.Printf("%05d: got packet %db, len: %db\n", connId, int(dataLen), len(buf2))
	log.Printf("data: %q", string(buf2))

	n, err := c.conn.Write(buf2)

	if err != nil {
		log.Printf("got err: %q\n", err)
	}

	log.Printf("packet was sent? %d\n", n)

	return 0
}

//export goUdpGwClient_FindConnectionByAddr
func goUdpGwClient_FindConnectionByAddr(cLocalAddr C.BAddr, cRemoteAddr C.BAddr) C.uint32_t {
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

	return C.uint32_t(connId)
}
