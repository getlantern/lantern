package tunio

import (
	"bytes"
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"unsafe"
)

/*
#include "tun2io.h"
#include "tun2io.c"
*/
import "C"

type tcpClient struct {
	client *C.struct_tcp_client

	written uint64
	acked   uint64

	buf  bytes.Buffer
	logn uint64

	pending bool

	tcpLock sync.Mutex
}

func (t *tcpClient) flushed() bool {
	t.log("written: %d, acked: %d", t.written, t.acked)
	return atomic.AddUint64(&t.written, 0) == atomic.AddUint64(&t.acked, 0)
}

func (t *tcpClient) accWritten(i uint64) uint64 {
	return atomic.AddUint64(&t.written, i)
}

func (t *tcpClient) accAcked(i uint64) uint64 {
	return atomic.AddUint64(&t.acked, i)
}

func (t *tcpClient) log(f string, args ...interface{}) {
	f = fmt.Sprintf("%d: (%04d) %s", t.tunnelID(), atomic.AddUint64(&t.logn, 1), f)
	log.Printf(f, args...)
}

func (t *tcpClient) tunnelID() C.uint32_t {
	if t != nil && t.client != nil {
		return t.client.tunnel_id
	}
	return 0
}

func (t *tcpClient) tcpWrite(chunk []byte) error {
	clen := len(chunk)
	cchunk := C.CString(string(chunk))
	defer C.free(unsafe.Pointer(cchunk))

	t.log("tcpWrite: tcp_write.")

	t.tcpLock.Lock()
	err_t := C.tcp_write(t.client.pcb, unsafe.Pointer(cchunk), C.uint16_t(clen), C.TCP_WRITE_FLAG_COPY)
	t.tcpLock.Unlock()

	switch err_t {
	case C.ERR_OK:
		t.log("tcpWrite: tcp_write. ERR_OK")
		return nil
	case C.ERR_MEM:
		t.log("tcpWrite: tcp_write. ERR_MEM")
		return errBufferIsFull
	}

	t.log("tcpWrite: tcp_write. unknown error.")
	return fmt.Errorf("Unknown error %d", int(err_t))
}

func (t *tcpClient) flush() error {
	t.log("flush: start")

	for {
		blen := t.buf.Len()

		mlen := t.sendBufSize()

		if mlen == 0 {
			t.log("flush: mlen = 0!")
			return errBufferIsFull
		}

		if blen > mlen {
			blen = mlen
			t.log("flush: mlen = %d!", mlen)
		}

		t.log("flush: blen = %d", blen)

		if blen == 0 {
			t.log("flush: nothing more to flush")
			break
		}

		chunk := make([]byte, blen)
		if _, err := t.buf.Read(chunk); err != nil {
			return err
		}

		if err := t.tcpWrite(chunk); err != nil {
			if err == errBufferIsFull {
				t.log("flush: buffer is full, let's flush it.")
				return t.tcpOutput()
			}
			t.log("flush: got another kind of error, let's abort.")
			return err
		}
	}

	return nil
}

func (t *tcpClient) sendBufSize() int {
	t.tcpLock.Lock()
	defer t.tcpLock.Unlock()
	return int(C.tcp_client_sndbuf(t.client))
}

func (t *tcpClient) tcpOutput() error {
	t.log("tcpOutput: about to force tcp_output.")
	t.tcpLock.Lock()
	err_t := C.tcp_client_output(t.client)
	t.tcpLock.Unlock()
	if err_t != C.ERR_OK {
		return fmt.Errorf("tcp_output: %d", int(err_t))
	}
	return nil
}
