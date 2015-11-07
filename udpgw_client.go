package tunio

import (
	"errors"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"
	"unsafe"
)

/*
#include "tun2io.h"
#include "tun2io.c"
*/
import "C"

var (
	udpgwMTU            int
	udpgwBufferSize     int
	udpgwMaxConnections int
	udpgwKeepAliveTime  time.Duration
	udpgwRetryTimeout   time.Duration = time.Millisecond * 500
)

var (
	errUdpGwNoSuchConn = errors.New("No such conn.")
)

type udpgwConn struct {
	net.Conn
	connIDs []uint16
}

type udpGwClient struct {
	connID uint16

	localAddr  string
	remoteAddr string

	conn net.Conn

	cLocalAddr  C.BAddr
	cRemoteAddr C.BAddr
}

func (c *udpGwClient) Close() {
	log.Printf("close client: %v", c)
	delete(udpgwConnIdMap, c.connID)
	delete(udpgwConnMap[c.localAddr], c.remoteAddr)
	if len(udpgwConnMap[c.localAddr]) == 0 {
		delete(udpgwConnMap, c.localAddr)
	}
}

var (
	udpgwConnPool   []*udpgwConn
	udpgwMessageIn  chan []byte
	udpgwMessageOut chan []byte
)

const (
	udpgwMaxConnPoolSize   = 3
	udpgwMaxClientsPerConn = 10
)

func udpgwInit() {
	udpgwConnMap = make(map[string]map[string]uint16)
	udpgwConnIdMap = make(map[uint16]*udpGwClient)
	udpgwConnPool = make([]*udpgwConn, 0, 10)
	udpgwMessageIn = make(chan []byte, 256)
	udpgwMessageOut = make(chan []byte, 256)

	go udpgwReaderService()
	go udpgwWriterService()
}

func udpgwReaderService() error {
	for message := range udpgwMessageIn {
		log.Printf("message in")
		cmessage := C.CString(string(message))
		C.udpGWClient_ReceiveFromServer(cmessage, C.int(len(message)))
		C.free(unsafe.Pointer(cmessage))
	}
	return nil
}

func udpgwWriterService() error {
	for message := range udpgwMessageOut {
		log.Printf("message out")
		for {
			// Get conn from pool.
			c := udpgwGetConnFromPool()
			// Attempt to write.
			_, err := c.Write(message)
			if err == nil {
				break
			}
			log.Printf("udpgwWriterService")
			c.Close()
			time.Sleep(udpgwRetryTimeout)
			log.Printf("w.Write: %q", err)
		}
	}
	return nil
}

func udpgwGetConnFromPool() *udpgwConn {
	if len(udpgwConnPool) < udpgwMaxConnPoolSize {
		// Create and return a new conn.
		conn := udpgwNewConn()
		if conn == nil {
			return nil
		}
		udpgwConnPool = append(udpgwConnPool, conn)
		return conn
	}

	// Return a random conn.
	for len(udpgwConnPool) > 0 {
		conn := udpgwConnPool[rand.Int()%len(udpgwConnPool)]
		if len(conn.connIDs) > udpgwMaxClientsPerConn {
			log.Printf("lets try to close.")
			// Conn is exhausted, let's close it.
			conn.Close()
		} else {
			return conn
		}
	}

	panic("exhausted.")
}

func udpgwNewConn() *udpgwConn {
	log.Printf("udpgwNewConn")
	conn, err := net.Dial("tcp", "10.4.4.120:5353")

	if err != nil {
		log.Printf("udpgwNewConn: %q", err)
		return nil
	}

	c := &udpgwConn{
		Conn:    conn,
		connIDs: make([]uint16, 0, udpgwMaxClientsPerConn),
	}

	go c.reader()

	return c
}

func (c *udpgwConn) Close() error {
	log.Printf("close...")

	c.Conn.Close()

	// also close associated clients
	if c.connIDs != nil {
		for _, connID := range c.connIDs {
			client := udpgwGetConnById(uint16(connID))
			client.Close()
		}
	}

	c.connIDs = nil

	newConn := udpgwNewConn()
	// remove current conn from pool
	for i := 0; i < len(udpgwConnPool); i++ {
		if udpgwConnPool[i] == c {
			if newConn == nil {
				udpgwConnPool = append(udpgwConnPool[:i], udpgwConnPool[i+1:]...)
			} else {
				udpgwConnPool[i] = newConn
			}
		}
	}

	return nil
}

func (c *udpgwConn) reader() error {
	defer c.Close()

	for {
		head := make([]byte, 2)
		n, err := c.Read(head)
		if err != nil {
			log.Printf("c.Read: %q", err)
			return err
		}
		if n > 0 {
			size := 0
			size += int(head[0])
			size += int(head[1]) << 8

			data := make([]byte, size)
			n, err := c.Read(data)
			if err != nil {
				return err
			}

			if n != size {
				panic("dont know how to handle this.")
				return errors.New("Got suspicious packet.")
			}

			udpgwMessageIn <- data
		}
	}

	return nil
}

//export goUdpGwClient_GetLocalAddrByConnId
func goUdpGwClient_GetLocalAddrByConnId(cConnID C.uint16_t) C.BAddr {
	conn := udpgwGetConnById(uint16(cConnID))
	return conn.cLocalAddr
}

//export goUdpGwClient_GetRemoteAddrByConnId
func goUdpGwClient_GetRemoteAddrByConnId(cConnID C.uint16_t) C.BAddr {
	conn := udpgwGetConnById(uint16(cConnID))
	return conn.cRemoteAddr
}

//export goUdpGwClient_ConnIdExists
func goUdpGwClient_ConnIdExists(cConnID C.uint16_t) C.int {
	conn := udpgwGetConnById(uint16(cConnID))
	if conn == nil {
		return C.ERR_ABRT
	}
	return C.ERR_OK
}

var (
	udpgwConnMap   map[string]map[string]uint16
	udpgwConnIdMap map[uint16]*udpGwClient
	udpgwConnMu    sync.Mutex
)

func udpgwGetConnById(connId uint16) *udpGwClient {
	return udpgwConnIdMap[connId]
}

func udpgwLookupConnId(localAddr, remoteAddr string) (uint16, error) {
	connId, ok := udpgwConnMap[localAddr][remoteAddr]
	if ok {
		return connId, nil
	}
	return 0, errUdpGwNoSuchConn
}

// udpgwLookupOrCreateConnId returns or creates a connection and returns the connection ID.
func udpgwLookupOrCreateConnId(localAddr, remoteAddr string) (uint16, error) {

	connId, err := udpgwLookupConnId(localAddr, remoteAddr)

	if err == nil {
		return connId, nil
	}

	if err == errUdpGwNoSuchConn {
		conn := udpgwGetConnFromPool()

		if conn == nil {
			return 0, errors.New("No connections in pool.")
		}

		client := &udpGwClient{
			conn:       conn,
			localAddr:  localAddr,
			remoteAddr: remoteAddr,
		}

		// Get ID
		udpgwConnMu.Lock()
		for {
			//connId = uint16(rand.Int31() % (1 << 16))
			connId = uint16(rand.Int31() % 50)
			if _, ok := udpgwConnIdMap[connId]; !ok {
				udpgwConnIdMap[connId] = client
				break
			}
			log.Printf("look...")
		}
		udpgwConnMu.Unlock()

		client.connID = connId
		conn.connIDs = append(conn.connIDs, connId)

		if udpgwConnMap[localAddr] == nil {
			udpgwConnMap[localAddr] = make(map[string]uint16)
		}

		log.Printf("Creating a new connection %s:%s (%d)...", localAddr, remoteAddr, connId)

		udpgwConnMap[localAddr][remoteAddr] = connId
	} else {
		return 0, err
	}

	return connId, nil
}

//export goUdpGwClient_Configure
// goUdpGwClient_Configure configures client values.
func goUdpGwClient_Configure(mtu C.int, maxConnections C.int, bufferSize C.int, keepAliveTime C.int) C.int {
	udpgwMTU = int(mtu)
	udpgwMaxConnections = int(maxConnections)
	udpgwBufferSize = int(bufferSize)
	udpgwKeepAliveTime = time.Second * time.Duration(int(keepAliveTime))

	log.Printf("MTU: %d", udpgwMTU)
	log.Printf("MaxConnections: %d", udpgwMaxConnections)
	log.Printf("BufferSize: %d", udpgwBufferSize)
	log.Printf("KeepAliveTime: %d", udpgwKeepAliveTime)

	return C.ERR_OK
}

//export goUdpGwClient_Send
// goUdpGwClient_Send sends a packet to the udpgw server.
func goUdpGwClient_Send(connId uint16, data *C.uint8_t, dataLen C.int) C.int {
	//c := udpgwGetConnById(connId)

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

	udpgwMessageOut <- buf

	return C.ERR_OK
}

//export goUdpGwClient_FindConnectionIdByAddr
// goUdpGwClient_FindConnectionIdByAddr returns a connection ID given local and
// remote addresses.
func goUdpGwClient_FindConnectionIdByAddr(cLocalAddr C.BAddr, cRemoteAddr C.BAddr) C.uint16_t {
	// Open a connection for localAddr and remoteAddr
	laddr := C.baddr_to_str(&cLocalAddr)
	raddr := C.baddr_to_str(&cRemoteAddr)

	defer func() {
		C.free(unsafe.Pointer(laddr))
		C.free(unsafe.Pointer(raddr))
	}()

	connId, err := udpgwLookupConnId(C.GoString(laddr), C.GoString(raddr))
	if err != nil {
		return 0
	}

	return C.uint16_t(connId)
}

//export goUdpGwClient_NewConnection
// goUdpGwClient_NewConnection creates a connection and returns a connection ID
// given local and remote addresses.
func goUdpGwClient_NewConnection(cLocalAddr C.BAddr, cRemoteAddr C.BAddr) C.uint16_t {

	// Open a connection for localAddr and remoteAddr
	laddr := C.baddr_to_str(&cLocalAddr)
	raddr := C.baddr_to_str(&cRemoteAddr)

	defer func() {
		C.free(unsafe.Pointer(laddr))
		C.free(unsafe.Pointer(raddr))
	}()

	localAddr := C.GoString(laddr)
	remoteAddr := C.GoString(raddr)

	connId, err := udpgwLookupOrCreateConnId(localAddr, remoteAddr)
	if err != nil {
		return 0
	}

	client := udpgwGetConnById(connId)

	client.cLocalAddr = cLocalAddr
	client.cRemoteAddr = cRemoteAddr

	return C.uint16_t(connId)
}
