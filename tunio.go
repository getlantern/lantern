package tunio

import (
	"fmt"
	"golang.org/x/net/context"
	"io"
	"log"
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

type TunIO struct {
	client *tcpClient

	destAddr string
	connOut  net.Conn

	status   Status
	statusMu sync.Mutex

	send chan []byte

	waitForReader chan bool
	waitForWriter chan bool

	lock sync.Mutex

	ctx       context.Context
	ctxCancel context.CancelFunc
}

func (t *TunIO) Lock() {
	t.lock.Lock()
}

func (t *TunIO) Unlock() {
	t.lock.Unlock()
}

func (t *TunIO) SetStatus(s Status) {
	t.statusMu.Lock()
	t.status = s
	t.statusMu.Unlock()
}

func (t *TunIO) Status() Status {
	t.statusMu.Lock()
	defer t.statusMu.Unlock()
	return t.status
}

func (t *TunIO) TunnelID() C.uint32_t {
	return t.client.tunnelID()
}

func (t *TunIO) canFlush() bool {
	s := t.Status()
	return s == StatusProxying || s == StatusClosing || s == StatusServerClosed
}

func (t *TunIO) flush() error {
	t.log("flush: request to flush")
	if t.canFlush() {
		for {
			err := t.client.flush()
			if err == nil {
				break
			}
			if err == errBufferIsFull {
				t.log("buffer is full!")
				time.Sleep(time.Millisecond * 500)
				continue
			} else {
				return fmt.Errorf("could not flush!")
			}
		}
	} else {
		t.log("flush: client is not proxying! %d", t.Status())
		return fmt.Errorf("client is not proxying!")
	}
	t.log("flush: flushed!")
	return nil
}

func (t *TunIO) sendMessage(message []byte) error {
	var err error
	t.client.accWritten(uint64(len(message)))
	if _, err = t.client.buf.Write(message); err != nil {
		t.log("sendMessage: could not write buffer: %q", err)
		return err
	}
	for t.client.buf.Len() > 0 {
		t.log("sendMessage: remaining: %d.", t.client.buf.Len())
		if err := t.flush(); err != nil {
			t.log("writerMessage: could not flush: %q", err)
			return err
		}
	}
	return nil
}

func (t *TunIO) writer(started chan error) error {
	started <- nil

	for {
		select {
		case <-t.ctx.Done():
			t.log("writer: done")
			return t.ctx.Err()
		case message, ok := <-t.send:
			if !ok {
				t.log("writer: closed channel")
				return nil
			}
			t.log("writer: got send message.")
			if err := t.sendMessage(message); err != nil {
				t.log("writer: sendMessage: %q", err)
				return err
			}
		}
	}

	t.log("writer: exiting writer")
	return nil
}

func (t *TunIO) quit(reason string) error {
	t.log("quit: start: %q", reason)

	status := t.Status()

	switch status {
	case StatusProxying:
	case StatusServerClosed:
	case StatusClosing:
		t.log("quit: already closing!")
		return fmt.Errorf("unexpected status %d", status)
	case StatusClosed:
		t.log("quit: already closed!")
		return fmt.Errorf("unexpected status %d", status)
	default:
		t.log("quit: expecting status StatusProxying, got %d", status)
		return fmt.Errorf("unexpected status %d", status)
	}

	t.Lock()
	defer t.Unlock()

	t.SetStatus(StatusClosing)

	if status == StatusProxying {
		t.log("quit: attempt to flush...")
		for i := 0; !t.client.flushed(); i++ {
			t.log("quit: some packages still need to be written (%d)...", i)
			time.Sleep(time.Millisecond * 100)
			if i > 10 {
				t.log("quit: sorry, can't continue waiting...")
				break
			}
		}
		t.log("quit: looks like the buffer was flushed...")
	}

	t.log("quit: connOut.Close()")
	err := t.connOut.Close()
	t.log("quit: connOut.Close(): %v", err)

	// Freeing client on the C side.
	if status == StatusProxying {
		//t.log("quit: C.client_close()")
		//C.client_close(t.client.client)
		//t.log("quit: C.client_close(): ok")
		t.log("quit: goTunnelDestroy")
		goTunnelDestroy(t.TunnelID())
		t.log("quit: goTunnelDestroy: ok")
	} else {
		t.log("quit: C.client_abort_client()")
		C.client_abort_client(t.client.client)
		t.log("quit: C.client_abort_client(): ok")
	}

	t.SetStatus(StatusClosed)

	t.log("quit: cancelled")

	t.ctxCancel()
	close(t.send)

	tunnelMu.Lock()
	delete(tunnels, uint32(t.TunnelID()))
	tunnelMu.Unlock()

	t.log("quit: ok")

	return nil
}

func (t *TunIO) log(f string, args ...interface{}) {
	if t.client != nil {
		t.client.log(f, args...)
	} else {
		log.Printf("(??!) "+f, args...)
	}
}

// reader is a goroutine that reads whatever the connOut (destination) //
// receives. After reading, the data is stored into the client buffer and a
// request to flush it is issued.
func (t *TunIO) reader(started chan error) error {
	started <- nil

	for {

		select {
		case <-t.ctx.Done():
			t.log("reader: done")
			return t.ctx.Err()
		default:
			data := make([]byte, readBufSize)
			t.connOut.SetReadDeadline(time.Now().Add(ioTimeout))
			t.log("reader: connOut.Read (reader is blocking)")
			n, err := t.connOut.Read(data)
			if err != nil {
				// Closing the connOut will also cause an error here.
				t.log("reader: t.connOut.Read: %q", err)
				if err == io.EOF {
					// Maybe wait for the buffer to fail or flush?
					//t.SetStatus(StatusServerClosed)
					t.log("reader: server closed connection.")
				}
				return err
			}
			t.log("reader: got read %d, %q", n, err)
			if n > 0 {
				t.log("D -> C: t.send <- data[0:%d].", n)
				if t.Status() == StatusProxying {
					t.send <- data[0:n]
				} else {
					t.log("Already closing...")
					break
				}
			}
		}

	}

	t.log("reader: exiting reader.")

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
		send:     make(chan []byte, 8),
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
