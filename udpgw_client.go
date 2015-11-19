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
	errUdpGwNoSuchConn        = errors.New("No such conn.")
	errUdpGwConnectionExpired = errors.New("Connection expired.")
)

var (
	udpgwClientList = NewConnList(10)
)

type udpgwConn struct {
	net.Conn
	closed  bool
	connIDs map[uint16]*udpGwClient
}

func setUdpGwClient(connID uint16, c *udpGwClient) error {
	udpgwConnMu.Lock()
	defer udpgwConnMu.Unlock()

	udpgwClientList.Add(int(connID), c)
	udpgwConnIdMap[connID] = c

	return nil
}

func unshiftUdpGwClient(connID uint16) error {
	// Push this connection to the head.
	c, err := getUdpGwClientById(connID)
	if err != nil {
		return err
	}
	return setUdpGwClient(connID, c)
}

func removeUdpGwClient(connID uint16) error {

	udpgwConnMu.Lock()
	c, ok := udpgwConnIdMap[connID]
	udpgwConnMu.Unlock()

	if !ok {
		return errUdpGwNoSuchConn
	}

	c.Close()

	return nil
}

func udpgwLookupConnId(localAddr, remoteAddr string) (uint16, error) {
	udpgwConnMu.Lock()
	connID, ok := udpgwConnMap[localAddr][remoteAddr]
	udpgwConnMu.Unlock()

	if !ok {
		return 0, errUdpGwNoSuchConn
	}

	v := udpgwClientList.Get(int(connID))

	if v == nil {
		removeUdpGwClient(connID)
		return 0, errUdpGwConnectionExpired
	}

	return connID, nil
}

func getUdpGwClientById(connID uint16) (*udpGwClient, error) {

	udpgwConnMu.Lock()
	_, ok := udpgwConnIdMap[connID]
	udpgwConnMu.Unlock()

	if !ok {
		return nil, errUdpGwNoSuchConn
	}

	v := udpgwClientList.Get(int(connID))

	if v == nil {
		removeUdpGwClient(connID)
		return nil, errUdpGwConnectionExpired
	}

	return v.(*udpGwClient), nil
}

type udpGwClient struct {
	connID uint16

	localAddr  string
	remoteAddr string

	conn *udpgwConn

	cLocalAddr  C.BAddr
	cRemoteAddr C.BAddr
}

func (c *udpGwClient) Close() {
	udpgwConnMu.Lock()
	defer udpgwConnMu.Unlock()

	udpgwClientList.Remove(int(c.connID))
	delete(udpgwConnIdMap, c.connID)
	delete(udpgwConnMap[c.localAddr], c.remoteAddr)
	if len(udpgwConnMap[c.localAddr]) == 0 {
		delete(udpgwConnMap, c.localAddr)
	}
	delete(c.conn.connIDs, c.connID)
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
		cmessage := C.CString(string(message))
		C.udpGWClient_ReceiveFromServer(cmessage, C.int(len(message)))
		C.free(unsafe.Pointer(cmessage))
	}
	return nil
}

func udpgwWriterService() error {
	for message := range udpgwMessageOut {
		for {
			log.Printf("udpgw: do write")
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

	// Return the conn with the least connections.
	var conn *udpgwConn
	var connN int

	for i := range udpgwConnPool {
		c := udpgwConnPool[i]
		if c.closed {
			c.Conn = udpgwNewConn()
			c.closed = false
		}
		n := len(c.connIDs)
		if i == 0 || n < connN {
			connN = n
			conn = c
		}
	}

	return conn
}

func udpgwNewConn() *udpgwConn {
	log.Printf("udpgwNewConn")
	conn, err := Dialer("tcp", udpGwServerAddress)

	if err != nil {
		log.Printf("udpgwNewConn: %q", err)
		return nil
	}

	c := &udpgwConn{
		Conn:    conn,
		connIDs: make(map[uint16]*udpGwClient),
	}

	go c.reader()

	return c
}

func (c *udpgwConn) Close() error {
	// Close underlying conn.
	c.Conn.Close()

	// Closing all clients.
	for connID := range c.connIDs {
		removeUdpGwClient(connID)
	}

	// Cancel connection.
	c.closed = true

	return nil
}

func (c *udpgwConn) reader() error {
	defer c.Close()

	for {
		head := make([]byte, 2)
		n, err := c.Read(head)
		log.Printf("udpgw: got read")
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
	if conn, err := getUdpGwClientById(uint16(cConnID)); err == nil {
		return conn.cLocalAddr
	}
	return C.BAddr{}
}

//export goUdpGwClient_GetRemoteAddrByConnId
func goUdpGwClient_GetRemoteAddrByConnId(cConnID C.uint16_t) C.BAddr {
	if conn, err := getUdpGwClientById(uint16(cConnID)); err == nil {
		return conn.cRemoteAddr
	}
	return C.BAddr{}
}

//export goUdpGwClient_ConnIdExists
func goUdpGwClient_ConnIdExists(cConnID C.uint16_t) C.int {
	if _, err := getUdpGwClientById(uint16(cConnID)); err == nil {
		return C.ERR_OK
	}
	return C.ERR_ABRT
}

var (
	udpgwConnMap   map[string]map[string]uint16
	udpgwConnIdMap map[uint16]*udpGwClient
	udpgwConnMu    sync.Mutex
)

// udpgwLookupOrCreateConnId returns or creates a connection and returns the connection ID.
func udpgwLookupOrCreateConnId(localAddr, remoteAddr string) (uint16, error) {

	connID, err := udpgwLookupConnId(localAddr, remoteAddr)

	if err == nil {
		return connID, nil
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
		for {
			//connID = uint16(rand.Int31() % (1 << 16))
			connID = uint16(rand.Int31() % 50)
			if _, err := getUdpGwClientById(connID); err != nil {
				setUdpGwClient(connID, client)
				break
			}
		}

		log.Printf("Creating a new connection %s:%s (%d)...", localAddr, remoteAddr, connID)

		client.connID = connID
		client.conn = conn

		conn.connIDs[connID] = client

		udpgwConnMu.Lock()
		if udpgwConnMap[localAddr] == nil {
			udpgwConnMap[localAddr] = make(map[string]uint16)
		}
		udpgwConnMap[localAddr][remoteAddr] = connID
		udpgwConnMu.Unlock()

	} else {
		return 0, err
	}

	return connID, nil
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
func goUdpGwClient_Send(connID uint16, data *C.uint8_t, dataLen C.int) C.int {

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

	connID, err := udpgwLookupConnId(C.GoString(laddr), C.GoString(raddr))
	if err != nil {
		return 0
	}

	return C.uint16_t(connID)
}

//export goUdpGwClient_UnshiftConn
func goUdpGwClient_UnshiftConn(connID uint16) {
	unshiftUdpGwClient(connID)
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

	connID, err := udpgwLookupOrCreateConnId(localAddr, remoteAddr)
	if err != nil {
		return 0
	}

	client, _ := getUdpGwClientById(connID)

	client.cLocalAddr = cLocalAddr
	client.cRemoteAddr = cRemoteAddr

	return C.uint16_t(connID)
}
