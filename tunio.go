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

const (
	readBufSize  = 1024 * 16 // CYGNUM_LWIP_TCP_SND_BUF
	writeBufSize = 1024 * 16
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
	client *C.struct_tcp_client
	//buf      bytes.Buffer
	written uint64
	acked   uint64
	outbuf  bytes.Buffer
	//outbufMu sync.Mutex
	//outMu    sync.Mutex
	//flushing bool
}

func (t *tcpClient) flushed() bool {
	t.log("written: %d, acked: %d", t.written, t.acked)
	return t.written == t.acked
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
	StatusClosing
	StatusClosed
)

type TunIO struct {
	client *tcpClient
	opMu   sync.Mutex

	destAddr string
	connOut  net.Conn
	//exitWriter chan bool
	//exitReader chan bool
	//writing    bool
	//reading    bool
	//closed     bool

	status   Status
	statusMu sync.Mutex

	send chan []byte
	ack  chan bool

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

func (t *TunIO) flush() error {
	t.log("flush: request to flush")
	if t.Status() != StatusProxying {
		t.log("flush: client is not proxying!")
		return fmt.Errorf("client is not proxying!")
	}
	if err := t.client.flush(); err != nil {
		t.log("flush: could not flush: %q", err)
		return fmt.Errorf("could not flush!")
	}
	t.log("flush: flushed!")
	return nil
}

func (t *TunIO) writer() error {
	t.waitForWriter <- true

	var err error

	for message := range t.send {
		t.log("writer: got send message.")
		if _, err = t.client.outbuf.Write(message); err != nil {
			t.log("writer: could not write buffer: %q", err)
			break
		}
		if err := t.flush(); err != nil {
			t.log("writer: could not flush: %q", err)
			break
		}
	}

	t.quit("writer: closed loop.")

	t.log("writer: exiting writer")
	return nil
}

func (t *TunIO) quit(reason string) error {
	t.log("quit: start: %q", reason)

	switch s := t.Status(); s {
	case StatusProxying:
	case StatusClosing:
		t.log("quit: already closing!")
		return fmt.Errorf("unexpected status %d", s)
	case StatusClosed:
		t.log("quit: already closed!")
		return fmt.Errorf("unexpected status %d", s)
	default:
		t.log("quit: expecting status StatusProxying, got %d", s)
		return fmt.Errorf("unexpected status %d", s)
	}

	t.Lock()
	defer t.Unlock()

	t.SetStatus(StatusClosing)

	for i := 0; !t.client.flushed(); i++ {
		t.log("quit: some packages still need to be written (%d)...", i)
		time.Sleep(time.Millisecond * 100)
		if i > 10 {
			t.log("quit: sorry, can't continue waiting...")
			break
		}
	}

	t.log("quit: connOut.Close()")
	err := t.connOut.Close()
	t.log("quit: connOut.Close(): %v", err)

	t.log("quit: close send")

	close(t.send)
	close(t.ack)

	// Freeing client on the C side.
	t.log("quit: C.client_close()")
	C.client_close(t.client.client)
	t.log("quit: C.client_close(): ok")

	t.SetStatus(StatusClosed)

	t.log("quit: ok")

	return nil
}

func (t *tcpClient) enqueue(chunk []byte) error {
	clen := len(chunk)
	cchunk := C.CString(string(chunk))
	defer C.free(unsafe.Pointer(cchunk))

	sleepTime := time.Millisecond * 80

	var j int

	for j = 0; j < maxEnqueueAttempts; j++ {
		t.log("enqueue: attempt %d", j)

		err_t := C.tcp_write(t.client.pcb, unsafe.Pointer(cchunk), C.uint16_t(clen), C.TCP_WRITE_FLAG_COPY)

		switch err_t {
		case C.ERR_OK:
			t.log("enqueue: ok")
			return nil
		case C.ERR_MEM:
			t.log("enqueue: C.ERR_MEM")
			// Could not enqueue anymore data, let's flush it and try again.
			if err := t.tcpOutput(); err != nil {
				t.log("enqueue: tcp output: %q", err)
				return err
			}
			// Last part was flushed, now continue and try to write again.
			t.log("enqueue: sleeping %v", sleepTime)
			time.Sleep(sleepTime)
			if sleepTime < maxWaitingTime {
				sleepTime = sleepTime * 2
			}
		default:
			t.log("enqueue: got unexpected error from tcp_write %q", err_t)
			return fmt.Errorf("tcp_write: %d", err_t)
		}
	}

	t.log("enqueue: giving up after %d/%d", j, maxEnqueueAttempts)

	return fmt.Errorf("Could not flush data. Giving up.")
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
			t.log("flush: nothing to flush")
			break
		}

		chunk := make([]byte, blen)
		if _, err := t.outbuf.Read(chunk); err != nil {
			return err
		}

		if err := t.enqueue(chunk); err != nil {
			return err
		}
	}

	return t.tcpOutput()
}

func (t *tcpClient) tcpOutput() error {
	err_t := C.tcp_output(t.client.pcb)
	if err_t != C.ERR_OK {
		return fmt.Errorf("tcp_output: %d", int(err_t))
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
				t.log("reader: server closed connection.")
			}
			break
		}
		t.log("reader: got read %d, %q", n, err)
		if n > 0 {
			t.log("D -> C: t.send <- data[0:%d].", n)
			if t.Status() == StatusProxying {
				t.client.accWritten(uint64(n))
				go func() {
					t.send <- data[0:n]
				}()
				//t.log("wait for ack")
				//<-t.ack
				//t.log("ack ok")
			} else {
				t.log("Already closing...")
				break
			}
		}
		for i := 0; !t.client.flushed(); i++ {
			t.log("reader: some packages still need to be written (%d)...", i)
			time.Sleep(time.Millisecond * 10)
			if i > 10 {
				t.quit("sorry, can't continue waiting...")
			}
		}
	}

	t.quit("reader: closed loop.")

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
		//exitWriter:    make(chan bool),
		//exitReader:    make(chan bool),
		//doFlush:       make(chan bool, 8),
		waitForReader: make(chan bool),
		waitForWriter: make(chan bool),
		send:          make(chan []byte),
		ack:           make(chan bool),
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
		if err := t.reader(); err != nil {
			t.quit(fmt.Sprintf("goreader: error: %q", err))
		}
		t.log("goreader: exit")
		delReader(t)
	}()

	go func() {
		addWriter(t)
		t.log("gowriter: start.")
		if err := t.writer(); err != nil {
			t.quit(fmt.Sprintf("gowriter: error: %q", err))
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

	if t.Status() != StatusProxying {
		t.log("expecting status StatusProxying, got %d", t.Status())
		return C.ERR_ABRT
	}

	if ok {
		size := int(size)
		buf := make([]byte, size)
		for i := 0; i < size; i++ {
			buf[i] = byte(C.charAt(write, C.int(i)))
		}

		t.log("connOut.Write: %dbytes", len(buf))

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
		log.Printf("%d: tunnel does not exist: %s", tunID, s)
		return
	}

	t.log(s)
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

	if t.Status() == StatusProxying {
		t.log("goTunnelSentACK: acknowledging %d...", int(dlen))
		t.client.accAcked(uint64(dlen))
	}

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
	if !ok {
		log.Printf("%d: goTunnelDestroy can't destroy, tunnel does not exist.", tunID)
		return C.ERR_ABRT
	}
	delete(tunnels, tunID)
	tunnelMu.Unlock()

	t.quit("goTunnelDestroy: C code request tunnel destruction...")

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
