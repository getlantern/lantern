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
	connID      int
	conn        net.Conn
	cLocalAddr  C.BAddr
	cRemoteAddr C.BAddr
}

//export goUdpGwClient_GetLocalAddrByConnId
func goUdpGwClient_GetLocalAddrByConnId(cConnID C.uint16_t) C.BAddr {
	conn := udpgwGetConnById(uint32(cConnID))
	return conn.cLocalAddr
}

func DialUDP() (net.Conn, error) {
	conn, err := net.Dial("tcp", "10.4.4.120:5353")
	if err != nil {
		return nil, err
	}
	go func() {
		for {
			buf := make([]byte, 256)
			n, err := conn.Read(buf)
			if err != nil {
				return
			}
			if n > 0 {
				if buf[1] != 0 {
					panic("Don't know how to handle this.")
				}
				size := int(buf[0])
				if n != size+2 {
					panic("Don't know how to handle this.")
				}
				data := buf[2:]
				log.Printf("data: %q\n", data)

				cchunk := C.CString(string(data))

				C.udpGWClient_ReceiveFromServer(cchunk, C.int(len(data)))
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
	if bl > 254 {
		panic("don't know how to send a packet larger than 254bytes.")
	}

	buf := make([]byte, 2+bl)

	buf[0] = byte(bl)
	buf[1] = 0

	for i := 0; i < bl; i++ {
		buf[i+2] = byte(C.dataAt(data, C.int(i)))
	}

	log.Printf("%05d: got packet %db, len: %db\n", connId, int(dataLen), len(buf))
	log.Printf("data: %q", string(buf))

	n, err := c.conn.Write(buf)

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

	client := udpgwGetConnById(connId)
	client.cLocalAddr = cLocalAddr
	client.cRemoteAddr = cRemoteAddr

	return C.uint32_t(connId)
}
