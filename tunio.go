package tunio

/*
#cgo CFLAGS: -c -std=gnu99 -DCGO=1 -DBADVPN_THREAD_SAFE=0 -DBADVPN_LINUX -DBADVPN_BREACTOR_BADVPN -D_GNU_SOURCE -DBADVPN_USE_SIGNALFD -DBADVPN_USE_EPOLL -DBADVPN_LITTLE_ENDIAN -Ibadvpn -Ibadvpn/lwip/src/include/ipv4 -Ibadvpn/lwip/src/include/ipv6 -Ibadvpn/lwip/src/include -Ibadvpn/lwip/custom
#cgo LDFLAGS: -lc -lrt -lpthread -static-libgcc -Wl,-Bstatic -ltun2io -L${SRCDIR}/lib/

static char charAt(char *in, int i) {
	return in[i];
}

#include "tun2io.h"
#include "tun2io.c"
*/
import "C"

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"
)

var (
	errBufferIsFull = errors.New("Buffer is full.")
)

const (
	readBufSize = 1024 * 16
)

const (
	maxEnqueueAttempts = 100
)

var ioTimeout = time.Second * 30

var (
	maxWaitingTime = time.Millisecond * 100
)

var (
	writers map[uint32]bool
	readers map[uint32]bool
)

var (
	writersMu sync.Mutex
	readersMu sync.Mutex
)

func addWriter(t *TunIO) {
	writersMu.Lock()
	writers[uint32(t.TunnelID())] = true
	writersMu.Unlock()
}

func delWriter(t *TunIO) {
	writersMu.Lock()
	delete(writers, uint32(t.TunnelID()))
	writersMu.Unlock()
}

func addReader(t *TunIO) {
	readersMu.Lock()
	readers[uint32(t.TunnelID())] = true
	readersMu.Unlock()
}

func delReader(t *TunIO) {
	readersMu.Lock()
	delete(readers, uint32(t.TunnelID()))
	readersMu.Unlock()
}

var tunnels map[uint32]*TunIO
var tunnelMu sync.Mutex

func init() {
	tunnels = make(map[uint32]*TunIO)

	writers = make(map[uint32]bool)
	readers = make(map[uint32]bool)

	rand.Seed(time.Now().UnixNano())

	go stats()
}

func stats() {
	for {
		tunnelMu.Lock()
		tlen := len(tunnels)
		tunnelMu.Unlock()

		writersMu.Lock()
		wlen := len(writers)
		writersMu.Unlock()

		readersMu.Lock()
		rlen := len(readers)
		readersMu.Unlock()

		log.Printf("stats: readers: %d, writers: %d, tunnels: %d", rlen, wlen, tlen)

		writersMu.Lock()
		tunnelMu.Lock()
		if wlen != tlen {
			for i := range writers {
				if _, ok := tunnels[i]; !ok {
					log.Printf("stats: zombie writer from tunnel %d.", i)
				}
			}
		}
		writersMu.Unlock()
		tunnelMu.Unlock()

		readersMu.Lock()
		tunnelMu.Lock()
		if wlen != tlen {
			for i := range readers {
				if _, ok := tunnels[i]; !ok {
					log.Printf("stats: zombie reader from tunnel %d.", i)
				}
			}
		}
		readersMu.Unlock()
		tunnelMu.Unlock()

		time.Sleep(time.Second * 1)
	}
}

type dialer func(proto, addr string) (net.Conn, error)

var Dialer dialer

func dummyDialer(proto, addr string) (net.Conn, error) {
	return net.Dial(proto, addr)
}

type tcpClient struct {
	client  *C.struct_tcp_client
	written uint64
	acked   uint64
	outbuf  bytes.Buffer
	closed  bool
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
	f = fmt.Sprintf("%d: %s", t.tunnelID(), f)
	log.Printf(f, args...)
}

func (t *tcpClient) tunnelID() C.uint32_t {
	return t.client.tunnel_id
}

type Status uint

const (
	StatusNew Status = iota
	StatusConnecting
	StatusConnectionFailed
	StatusConnected
	StatusReady
	StatusProxying
	StatusServerClosed
	StatusClosing
	StatusClosed
)

type TunIO struct {
	client *tcpClient
	opMu   sync.Mutex

	destAddr string
	connOut  net.Conn

	status   Status
	statusMu sync.Mutex

	send chan []byte

	waitForReader chan bool
	waitForWriter chan bool

	lock sync.Mutex
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
		if err := t.client.flush(); err != nil {
			t.log("flush: could not flush: %q", err)
			return fmt.Errorf("could not flush!")
		}
	} else {
		t.log("flush: client is not proxying! %d", t.Status())
		return fmt.Errorf("client is not proxying!")
	}
	t.log("flush: flushed!")
	return nil
}

func (t *TunIO) writeMessage(message []byte) error {
	var err error
	t.client.accWritten(uint64(len(message)))
	if _, err = t.client.outbuf.Write(message); err != nil {
		t.log("writeMessage: could not write buffer: %q", err)
		return err
	}
	for t.client.outbuf.Len() > 0 {
		t.log("writeMessage: remaining: %d.", t.client.outbuf.Len())
		if err := t.flush(); err != nil {
			t.log("writerMessage: could not flush: %q", err)
			return err
		}
	}
	return nil
}

func (t *TunIO) writer() error {
	t.waitForWriter <- true

	for message := range t.send {
		t.log("writer: got send message.")
		t.writeMessage(message)
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

	t.log("quit: ok")

	return nil
}

func (t *tcpClient) enqueue(chunk []byte) error {
	clen := len(chunk)
	cchunk := C.CString(string(chunk))
	defer C.free(unsafe.Pointer(cchunk))

	t.log("enqueue: tcp_write.")
	err_t := C.tcp_write(t.client.pcb, unsafe.Pointer(cchunk), C.uint16_t(clen), C.TCP_WRITE_FLAG_COPY)

	switch err_t {
	case C.ERR_OK:
		t.log("enqueue: tcp_write. ERR_OK")
		return nil
	case C.ERR_MEM:
		t.log("enqueue: tcp_write. ERR_MEM")
		return errBufferIsFull
	}

	t.log("enqueue: tcp_write. unknown error.")
	return fmt.Errorf("Unknown error %d", int(err_t))
}

// flush will keep flushing data until the buffer is empty.
func (t *tcpClient) flush() error {
	t.log("flush: start")

	for {
		blen := t.outbuf.Len()
		mlen := int(C.tcp_client_sndbuf(t.client))

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
		if _, err := t.outbuf.Read(chunk); err != nil {
			return err
		}

		if err := t.enqueue(chunk); err != nil {
			if err == errBufferIsFull {
				t.log("flush: buffer is full, let's flush it.")
				break
			}
			t.log("flush: other kind of error, let's abort.")
			return err
		}
	}

	return t.tcpOutput()
}

func (t *tcpClient) tcpOutput() error {
	if !t.closed {
		t.log("tcpOutput: about to force tcp_output.")
		err_t := C.tcp_client_output(t.client)
		if err_t != C.ERR_OK {
			return fmt.Errorf("tcp_output: %d", int(err_t))
		}
	} else {
		t.log("tcpOutput: can't force tcp output, closed.")
	}
	return nil
}

func (t *TunIO) log(f string, args ...interface{}) {
	t.client.log(f, args...)
}

// reader is a goroutine that reads whatever the connOut (destination) //
// receives. After reading, the data is stored into the client buffer and a
// request to flush it is issued.
func (t *TunIO) reader() error {
	t.waitForReader <- true

	for {
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
				t.client.closed = true
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

	t.log("reader: exiting reader.")

	return nil
}

// NewTunnel creates a tunnel to the destination indicated by client using the
// given dialer function.
func NewTunnel(client *C.struct_tcp_client, d dialer) (*TunIO, error) {
	destAddr := C.dump_dest_addr(client)
	defer C.free(unsafe.Pointer(destAddr))

	t := &TunIO{
		client:        &tcpClient{client: client},
		destAddr:      C.GoString(destAddr),
		waitForReader: make(chan bool),
		waitForWriter: make(chan bool),
		send:          make(chan []byte, 16),
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

//export goNewTunnel
// goNewTunnel is called from listener_accept_func. It creates a tunnel and
// assigns an unique ID to it.
func goNewTunnel(client *C.struct_tcp_client) C.uint32_t {
	var i uint32

	t, err := NewTunnel(client, Dialer)
	if err != nil {
		log.Printf("Could not start tunnel: %q", err)
		return 0
	}

	// Looking for an unused ID to identify this tunnel.
	tunnelMu.Lock()
	for {
		i = uint32(rand.Int31())
		if _, ok := tunnels[i]; !ok {
			tunnels[i] = t
			break
		}
	}
	tunnelMu.Unlock()

	t.SetStatus(StatusReady)

	return C.uint32_t(i)
}

//export goInitTunnel
// goInitTunnel sets up the reader and writer goroutines that help
// proxying content.
func goInitTunnel(tunno C.uint32_t) C.int {
	tunID := uint32(tunno)

	tunnelMu.Lock()
	t, ok := tunnels[tunID]
	tunnelMu.Unlock()

	if !ok {
		return C.ERR_ABRT
	}

	t.Lock()
	defer t.Unlock()

	t.log("spawning reader and writer...")

	go func() {
		addReader(t)
		t.log("goreader: start.")
		err := t.reader()
		t.log("goreader: exit with error: %q", err)
		close(t.send)
		delReader(t)
	}()

	go func() {
		addWriter(t)
		t.log("gowriter: start.")
		if err := t.writer(); err != nil {
			t.quit(fmt.Sprintf("gowriter: error: %q", err))
		} else {
			t.quit("writer: closed loop.")
		}
		t.log("gowriter: exit")
		delWriter(t)
	}()

	<-t.waitForReader
	<-t.waitForWriter

	t.SetStatus(StatusProxying)

	t.log("tunnel is ready.")
	return C.ERR_OK
}

//export goTunnelWrite
// goTunnelWrite sends data from the client to the destination.
func goTunnelWrite(tunno C.uint32_t, write *C.char, size C.size_t) C.int {
	tunnelMu.Lock()
	t, ok := tunnels[uint32(tunno)]
	tunnelMu.Unlock()

	t.log("C -> D: goTunnelWrite: %d bytes.", int(size))

	t.Lock()
	defer t.Unlock()

	if ok {
		size := int(size)
		buf := make([]byte, size)
		for i := 0; i < size; i++ {
			buf[i] = byte(C.charAt(write, C.int(i)))
		}

		t.log("connOut.Write: %d bytes", len(buf))

		if s := t.Status(); s != StatusProxying {
			t.log("expecting status StatusProxying, got %d", s)
			return C.ERR_ABRT
		}

		t.connOut.SetWriteDeadline(time.Now().Add(ioTimeout))
		_, err := t.connOut.Write(buf)
		if err == nil {
			t.log("connOut.Write: OK")
			return C.ERR_OK
		}

		t.quit(fmt.Sprintf("got write error: %q", err))
	}

	log.Printf("%d: client is not registered!", int(tunno))

	return C.ERR_ABRT
}

//export goInspect
func goInspect(data *C.struct_tcp_pcb) {
	log.Printf("INSPECT: %#v", data)
}

//export goLog
func goLog(client *C.struct_tcp_client, c *C.char) {
	s := C.GoString(c)

	if client == nil {
		log.Printf("nil client: %s", s)
		return
	}

	tunID := uint32(client.tunnel_id)

	tunnelMu.Lock()
	t, ok := tunnels[tunID]
	tunnelMu.Unlock()

	if !ok {
		log.Printf("%d: (???!): %s", tunID, s)
		return
	}

	t.log(fmt.Sprintf("C: %s", s))
}

//export goTunnelSentACK
// goTunnelSentACK acknowledges a tunnel sent.
func goTunnelSentACK(tunno C.uint32_t, dlen C.u16_t) C.int {
	tunID := uint32(tunno)
	log.Printf("%d: goTunnelSentACK", tunID)

	tunnelMu.Lock()
	t, ok := tunnels[tunID]
	tunnelMu.Unlock()

	if !ok {
		return C.ERR_ABRT
	}

	t.log("goTunnelSentACK: acknowledging %d...", int(dlen))
	t.client.accAcked(uint64(dlen))

	t.log("goTunnelSentACK: wrote ack %d...", int(dlen))

	return C.ERR_OK
}

//export goTunnelDestroy
// goTunnelDestroy aborts all tunnel connections and removes the tunnel.
func goTunnelDestroy(tunno C.uint32_t) C.int {
	tunID := uint32(tunno)
	log.Printf("%d: goTunnelDestroy", tunID)

	tunnelMu.Lock()
	t, ok := tunnels[tunID]
	tunnelMu.Unlock()

	if !ok {
		log.Printf("%d: goTunnelDestroy can't destroy, tunnel does not exist.", tunID)
		return C.ERR_ABRT
	}

	t.quit("goTunnelDestroy: C code request tunnel destruction...")

	tunnelMu.Lock()
	delete(tunnels, tunID)
	tunnelMu.Unlock()

	return C.ERR_OK
}

// Configure sets up the tundevice, this is equivalent to the badvpn-tun2socks
// configuration, except for the --socks-server-addr.
func Configure(tundev, ipaddr, netmask string, d dialer) error {
	if d == nil {
		d = dummyDialer
	}

	Dialer = d

	ctundev := C.CString(tundev)
	cipaddr := C.CString(ipaddr)
	cnetmask := C.CString(netmask)

	defer func() {
		C.free(unsafe.Pointer(ctundev))
		C.free(unsafe.Pointer(cipaddr))
		C.free(unsafe.Pointer(cnetmask))
	}()

	if err_t := C.configure(ctundev, cipaddr, cnetmask); err_t != C.ERR_OK {
		return errors.New("Failed to configure device.")
	}

	return nil
}
