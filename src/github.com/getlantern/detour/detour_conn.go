package detour

import (
	"io"
	"net"
	"sync/atomic"
)

type detourConn struct {
	net.Conn
	addr string
	// 1 == true, 0 == false
	valid uint32
	// keep track of the total bytes read in this connection
	readBytes uint64

	// 1 == true, 0 == false, atomic
	markClose uint32

	// 1 == true, 0 == false, atomic
	errorEncountered uint32
}

func DialDetour(network string, addr string, dialer dialFunc, ch chan conn) {
	go func() {
		conn, err := dialer(network, addr)
		if err != nil {
			log.Errorf("Dial detour to %s failed: %s", addr, err)
			return
		}
		log.Tracef("Dial detour to %s succeeded", addr)
		ch <- &detourConn{Conn: conn, addr: addr, valid: 1, readBytes: 0}
	}()
	return
}

func (dc *detourConn) ConnType() connType {
	return connTypeDetour
}

func (dc *detourConn) Valid() bool {
	return atomic.LoadUint32(&dc.valid) == 1
}

func (dc *detourConn) SetInvalid() {
	atomic.StoreUint32(&dc.valid, 0)
	atomic.StoreUint32(&dc.markClose, 1)
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
		if atomic.LoadUint32(&dc.markClose) == 1 {
			dc.Conn.Close()
		}
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
		if atomic.LoadUint32(&dc.markClose) == 1 {
			dc.Conn.Close()
		}
		defer func() { ch <- ioResult{n, err, dc} }()
	}()
	return
}

func (dc *detourConn) Close() {
	atomic.StoreUint32(&dc.markClose, 1)
	if atomic.LoadUint64(&dc.readBytes) > 0 && atomic.LoadUint32(&dc.errorEncountered) == 0 {
		log.Tracef("no error found till closing, add %s to whitelist", dc.addr)
		AddToWl(dc.addr, false)
	}
}
