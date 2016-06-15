package netx

import (
	"io"
	"net"
	"sync/atomic"
	"time"
)

var (
	copyTimeout = 1 * time.Second
)

// BidiCopy copies between in and out in both directions using the specified
// buffers, returning the errors from copying to out and copying to in.
func BidiCopy(out net.Conn, in net.Conn, bufOut []byte, bufIn []byte) (outErr error, inErr error) {
	stop := uint32(0)
	outErrCh := make(chan error, 1)
	inErrCh := make(chan error, 1)
	go doCopy(out, in, bufIn, outErrCh, &stop)
	go doCopy(in, out, bufOut, inErrCh, &stop)
	return <-outErrCh, <-inErrCh
}

// doCopy is based on io.copyBuffer
func doCopy(dst net.Conn, src net.Conn, buf []byte, errCh chan error, stop *uint32) {
	var err error
	defer func() {
		atomic.StoreUint32(stop, 1)
		errCh <- err
	}()

	for {
		if atomic.LoadUint32(stop) == 1 {
			break
		}
		deadline := time.Now().Add(copyTimeout)
		src.SetReadDeadline(deadline)
		dst.SetWriteDeadline(deadline)
		nr, er := src.Read(buf)
		if nr > 0 {
			nw, ew := dst.Write(buf[0:nr])
			if ew != nil && !isTimeout(err) {
				err = ew
				break
			}
			if nr != nw {
				err = io.ErrShortWrite
				break
			}
		}
		if er == io.EOF {
			break
		}
		if er != nil && !isTimeout(er) {
			err = er
			break
		}
	}
}

func isTimeout(err error) bool {
	if netErr, ok := err.(net.Error); ok {
		return netErr.Timeout()
	}
	return false
}
