package tunio

import (
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"unsafe"
)

/*
#include "tun2io.c"
*/
import "C"

type tcpClient struct {
	client *C.struct_tcp_client
	mu     sync.Mutex

	written uint64
	acked   uint64

	buf  Buffer
	logn uint64
}

func (t *tcpClient) flushed() bool {
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

// tcpWrite wraps tcp_write.
func (t *tcpClient) tcpWrite(chunk []byte) error {
	clen := len(chunk)
	cchunk := C.CString(string(chunk))
	defer C.free(unsafe.Pointer(cchunk))

	t.mu.Lock()
	err_t := C.tcp_write(t.client.pcb, unsafe.Pointer(cchunk), C.uint16_t(clen), C.TCP_WRITE_FLAG_COPY)
	t.mu.Unlock()

	switch err_t {
	case C.ERR_OK:
		t.accWritten(uint64(clen))
		return nil
	case C.ERR_MEM:
		return errBufferIsFull
	}

	return fmt.Errorf("C.tcp_write: %d", int(err_t))
}

// sndBufSize wraps client_sndbuf
func (t *tcpClient) sndBufSize() uint {

	t.mu.Lock()
	s := C.tcp_client_sndbuf(t.client)
	t.mu.Unlock()

	return uint(s)
}

// tcpOutput wraps tcp_output.
func (t *tcpClient) tcpOutput() error {
	t.mu.Lock()
	err_t := C.tcp_output(t.client.pcb)
	t.mu.Unlock()

	if err_t != C.ERR_OK {
		return fmt.Errorf("C.tcp_output: %d", int(err_t))
	}

	return nil
}
