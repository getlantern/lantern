package detour

import (
	"io"
	"net"
	"sync/atomic"
)

type detourConn struct {
	net.Conn
	addr string
	// keep track of the total bytes read in this connection
	readBytes uint64

	// 1 == true, 0 == false, atomic
	errorEncountered uint32
	// a flag telling if connection is closed
	closed uint32
}

func dialDetour(network string, addr string, dialer dialFunc, ch chan conn) {
	go func() {
		log.Tracef("Dialing detour connection to %s", addr)
		conn, err := dialer(network, addr)
		if err != nil {
			log.Errorf("Dial detour to %s failed: %s", addr, err)
			return
		}
		log.Tracef("Dial detour to %s succeeded", addr)
		ch <- &detourConn{Conn: conn, addr: addr, readBytes: 0}
	}()
	return
}

func (dc *detourConn) ConnType() connType {
	return connTypeDetour
}

func (dc *detourConn) FirstRead(b []byte, ch chan ioResult) {
	dc.doRead(b, ch)
}

func (dc *detourConn) FollowupRead(b []byte, ch chan ioResult) {
	dc.doRead(b, ch)
}

func (dc *detourConn) doRead(b []byte, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Read(b)
		atomic.AddUint64(&dc.readBytes, uint64(n))
		defer func() { ch <- ioResult{n, err, dc} }()
		if err != nil {
			if err != io.EOF {
				atomic.AddUint32(&dc.errorEncountered, 1)
			}
			return
		}
	}()
	return
}

func (dc *detourConn) Write(b []byte, ch chan ioResult) {
	go func() {
		n, err := dc.Conn.Write(b)
		ch <- ioResult{n, err, dc}
	}()
	return
}

func (dc *detourConn) Close() (err error) {
	err = dc.Conn.Close()
	if atomic.LoadUint64(&dc.readBytes) > 0 && atomic.LoadUint32(&dc.errorEncountered) == 0 {
		log.Tracef("no error found till closing, add %s to whitelist", dc.addr)
		AddToWl(dc.addr, false)
	}
	atomic.StoreUint32(&dc.closed, 1)
	return
}

func (dc *detourConn) Closed() bool {
	return atomic.LoadUint32(&dc.closed) == 1
}
