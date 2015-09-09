package interceptor

import (
	"io"
	"net"
	"sync"
)

type InterceptedConn struct {
	net.Conn
	interceptor    *interceptor
	downstreamConn net.Conn
}

type Conns struct {
	mutex    sync.Mutex
	isClosed bool
	conns    map[net.Conn]bool
}

func (conn *InterceptedConn) Read(buffer []byte) (n int, err error) {
	n, err = conn.Conn.Read(buffer)
	if err != nil && err != io.EOF {
		select {
		case conn.interceptor.failureCount <- 1:
		default:
		}
	}
	return
}

func (conn *InterceptedConn) Write(buffer []byte) (n int, err error) {
	n, err = conn.Conn.Write(buffer)
	if err != nil && err != io.EOF {
		// Same as InterceptedConn.Read()
		select {
		case conn.interceptor.failureCount <- 1:
		default:
		}
	}
	return
}

func (conns *Conns) Reset() {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	conns.isClosed = false
	conns.conns = make(map[net.Conn]bool)
}

func (conns *Conns) Add(conn net.Conn) bool {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	if conns.isClosed {
		return false
	}
	if conns.conns == nil {
		conns.conns = make(map[net.Conn]bool)
	}
	conns.conns[conn] = true
	return true
}

func (conns *Conns) Remove(conn net.Conn) {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	delete(conns.conns, conn)
}

func (conns *Conns) CloseAll() {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	conns.isClosed = true
	for conn, _ := range conns.conns {
		conn.Close()
	}
	conns.conns = make(map[net.Conn]bool)
}
