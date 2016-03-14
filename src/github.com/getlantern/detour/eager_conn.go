package detour

import (
	"io"
	"net"
)

const (
	readSize = 8192
)

type read struct {
	b   []byte
	n   int
	err error
}

type eagerconn struct {
	net.Conn
	leftOverBytes []byte
	reads         chan *read
	lastRead      *read
}

func newEagerconn(orig net.Conn, bufferSize int) net.Conn {
	conn := &eagerconn{
		Conn:  orig,
		reads: make(chan *read, bufferSize/readSize),
	}

	go func() {
		// TODO: use buffer pool
		for {
			b := make([]byte, 8192)
			n, err := orig.Read(b)
			log.Tracef("Eager read %d: %v", n, err)
			conn.reads <- &read{b[:n], n, err}
			if err != nil {
				log.Trace("Done eager reading")
				close(conn.reads)
				return
			}
		}
	}()

	return conn
}

func (conn *eagerconn) Read(b []byte) (int, error) {
	if conn.leftOverBytes != nil {
		n := len(b)
		if n > len(conn.leftOverBytes) {
			n = len(conn.leftOverBytes)
		}
		copy(b, conn.leftOverBytes[:n])
		if n == len(conn.leftOverBytes) {
			conn.leftOverBytes = nil
		} else {
			conn.leftOverBytes = conn.leftOverBytes[n:]
		}
		log.Tracef("Drained %d left over buffered bytes", n)
		return n, nil
	}
	if conn.lastRead != nil && conn.lastRead.err != nil {
		log.Trace("Returning error from last read")
		return 0, conn.lastRead.err
	}
	log.Trace("Reading")
	// TODO: implement deadline handling
	read, ok := <-conn.reads
	log.Debugf("Read %d: %v", read.n, read.err)
	if !ok {
		return 0, io.EOF
	}
	if read.n == 0 && read.err != nil {
		log.Tracef("Error on eager read, returning immediately: %v", read.err)
		return 0, read.err
	}
	conn.lastRead = read
	n := copy(b, read.b)
	if n < len(read.b) {
		conn.leftOverBytes = read.b[n:]
		log.Tracef("Incomplete read, storing %d left over bytes", len(conn.leftOverBytes))
	}
	log.Tracef("Read %d", n)
	return n, nil
}
