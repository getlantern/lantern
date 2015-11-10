package interceptor

import (
	"io"
	"net"
	"sync"
)

type InterceptedConn struct {
	net.Conn
	id          string
	interceptor *Interceptor
	localConn   net.Conn
}

type Conns struct {
	mutex    sync.Mutex
	isClosed bool
	conns    map[net.Conn]bool
	count    int
}

func (conn *InterceptedConn) RemoveConn() {
	i := conn.interceptor
	i.connsMutex.Lock()
	i.conns[conn.id] = nil
	i.connsMutex.Unlock()
}

func (conn *InterceptedConn) Close() error {
	log.Debugf("Closing a connection with id: %s:%s", conn.LocalAddr(),
		conn.RemoteAddr())
	conn.RemoveConn()

	if conn.localConn != nil {
		conn.localConn.Close()
	}
	return conn.Conn.Close()
}

func (conn *InterceptedConn) Read(buffer []byte) (n int, err error) {

	n, err = conn.Conn.Read(buffer)
	if err != nil && err != io.EOF {
		log.Debugf("Got a read error with connection %v", conn)
		go func() {
			conn.interceptor.errCh <- err
		}()
	}
	return
}

func (conn *InterceptedConn) Write(buffer []byte) (n int, err error) {

	n, err = conn.Conn.Write(buffer)
	if err != nil && err != io.EOF {
		log.Debugf("Got a write error with connection %v", conn)
		go func() {
			conn.interceptor.errCh <- err
		}()
	}
	return
}

func (conns *Conns) Reset() {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	conns.isClosed = false
	conns.conns = make(map[net.Conn]bool)
}

func (conns *Conns) Size() int {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	return conns.count
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
	if !conns.conns[conn] {
		conns.count++
	}
	conns.conns[conn] = true
	return true
}

func (conns *Conns) Remove(conn net.Conn) {
	conns.mutex.Lock()
	defer conns.mutex.Unlock()
	delete(conns.conns, conn)
	conns.count--
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
