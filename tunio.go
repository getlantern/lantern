package tunio

import (
	"errors"
	"fmt"
	"golang.org/x/net/context"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"
)

/*
#include "tun2io.h"
#include "tun2io.c"
*/
import "C"

type TunIO struct {
	client *tcpClient

	destAddr string
	connOut  net.Conn

	status   Status
	statusMu sync.Mutex

	chunk chan []byte

	writing atomic.Value

	ctx       context.Context
	ctxCancel context.CancelFunc
}

func (t *TunIO) SetStatus(s Status) {
	t.statusMu.Lock()
	t.status = s
	t.statusMu.Unlock()
}

func (t *TunIO) Status() Status {
	t.statusMu.Lock()
	s := t.status
	t.statusMu.Unlock()
	return s
}

func (t *TunIO) TunnelID() C.uint32_t {
	return t.client.tunnelID()
}

func (t *TunIO) setWriting(v bool) {
	t.writing.Store(v)
}

func (t *TunIO) isWriting() bool {
	v := t.writing.Load()
	return v != nil && v.(bool)
}

func (t *TunIO) writeToClient() error {

	if t.isWriting() {
		return errors.New("Already writing.")
	}

	t.setWriting(true)
	defer t.setWriting(false)

	// Sends tcp writes until tcp send buffer is full.
	for {

		blen := uint(t.client.buf.Len())
		if blen == 0 {
			return nil
		}

		mlen := t.client.sndBufSize()
		if mlen == 0 {
			// At this point the actual tcp send buffer is full, let's wait for some
			// acks to try again.
			return errBufferIsFull
		}

		if blen > mlen {
			blen = mlen
		}

		chunk := make([]byte, blen)
		if _, err := t.client.buf.Read(chunk); err != nil {
			return err
		}

		// Enqueuing chunk.
		select {
		case t.chunk <- chunk:
		case <-t.ctx.Done():
			return t.ctx.Err()
		}
	}
}

func (t *TunIO) writer(started chan error) error {
	started <- nil

	for {
		select {
		case <-t.ctx.Done():
			return t.ctx.Err()
		case chunk := <-t.chunk:
			// Send tcp chunk.
			for i := 0; ; i++ {
				err := t.client.tcpWrite(chunk)
				if err == nil {
					break
				}
				if err == errBufferIsFull {
					/*
						if err = t.client.tcpOutput(); err != nil {
							t.log("writer: tcpOutput: %q", err)
							return err
						}
					*/
					time.Sleep(time.Millisecond * 10)
					continue
				}
				return err
			}
		}
	}

	return nil
}

// quit closes the proxy
func (t *TunIO) quit(reason string) error {
	status := t.Status()

	if status != StatusProxying {
		return fmt.Errorf("unexpected status %d", status)
	}

	//t.log("quit: %q", reason)

	t.SetStatus(StatusClosing)

	t.connOut.Close()

	t.SetStatus(StatusClosed)

	t.ctxCancel()

	tunnelMu.Lock()
	delete(tunnels, uint32(t.TunnelID()))
	tunnelMu.Unlock()

	return nil
}

func (t *TunIO) log(f string, args ...interface{}) {
	if t.client != nil {
		t.client.log(f, args...)
	} else {
		log.Printf("(??!) "+f, args...)
	}
}

// reader is the goroutine that reads whatever the connOut proxied destination
// receives and writes it to a buffer.
func (t *TunIO) reader(started chan error) error {
	started <- nil

	for {
		select {
		case <-t.ctx.Done():
			return t.ctx.Err()
		default:
			data := make([]byte, readBufSize)
			t.connOut.SetReadDeadline(time.Now().Add(ioTimeout))
			n, err := t.connOut.Read(data)
			if err != nil {
				return err
			}
			if n > 0 {
				t.client.buf.Write(data[0:n])
				go t.writeToClient()
			}
		}
	}

	return nil
}

// NewTunnel creates a tunnel to the destination indicated by client using the
// given dialer function.
func NewTunnel(client *C.struct_tcp_client, d dialer) (*TunIO, error) {
	destAddr := C.dump_dest_addr(client)
	defer C.free(unsafe.Pointer(destAddr))

	t := &TunIO{
		client:   &tcpClient{client: client},
		destAddr: C.GoString(destAddr),
		chunk:    make(chan []byte, 256),
	}

	t.SetStatus(StatusConnecting)

	var err error
	if t.connOut, err = d("tcp", t.destAddr); err != nil {
		t.SetStatus(StatusConnectionFailed)
		return nil, err
	}

	t.SetStatus(StatusConnected)

	return t, nil
}
