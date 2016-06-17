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
// buffers, returning the errors from copying to out and copying to in. BidiCopy
// continues trying to write out to the respective connections for up to
// writeTimeout to flush any buffered data before giving up and returning
// io.ErrShortWrite.
func BidiCopy(out net.Conn, in net.Conn, bufOut []byte, bufIn []byte, writeTimeout time.Duration) (outErr error, inErr error) {
	stop := uint32(0)
	outErrCh := make(chan error, 1)
	inErrCh := make(chan error, 1)
	go doCopy(out, in, bufIn, writeTimeout, outErrCh, &stop)
	go doCopy(in, out, bufOut, writeTimeout, inErrCh, &stop)
	return <-outErrCh, <-inErrCh
}

// doCopy is based on io.copyBuffer
func doCopy(dst net.Conn, src net.Conn, buf []byte, writeTimeout time.Duration, errCh chan error, stop *uint32) {
	var err error
	defer func() {
		atomic.StoreUint32(stop, 1)
		errCh <- err
	}()

	for {
		if atomic.LoadUint32(stop) == 1 {
			return
		}
		deadline := time.Now().Add(copyTimeout)
		src.SetReadDeadline(deadline)
		dst.SetWriteDeadline(deadline)
		nr, er := src.Read(buf)
		if nr > 0 {
			ew := writeTo(dst, buf[0:nr], writeTimeout)
			if ew != nil {
				err = ew
				return
			}
		}
		if er == io.EOF {
			return
		}
		if er != nil && !isTimeout(er) {
			err = er
			return
		}
	}
}

func writeTo(dst net.Conn, buf []byte, writeTimeout time.Duration) error {
	nw := 0
	writeStart := time.Now()
	for {
		nww, err := dst.Write(buf)
		nw += nww
		if err != nil && !isTimeout(err) {
			return err
		}
		if nw == len(buf) {
			return nil
		}
		if time.Now().Sub(writeStart) > writeTimeout {
			return io.ErrShortWrite
		}
	}
}

func isTimeout(err error) bool {
	if netErr, ok := err.(net.Error); ok {
		return netErr.Timeout()
	}
	return false
}
