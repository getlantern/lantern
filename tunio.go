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
	"time"
	"unsafe"
)

const (
	readBufSize  = 1024 * 16 // CYGNUM_LWIP_TCP_SND_BUF
	writeBufSize = 1024 * 16
)

var tunnels map[uint32]*TunIO
var tunnelMu sync.Mutex

func init() {
	tunnels = make(map[uint32]*TunIO)
	rand.Seed(time.Now().UnixNano())
}

type dialer func(proto, addr string) (net.Conn, error)

var Dialer dialer

func dummyDialer(proto, addr string) (net.Conn, error) {
	return net.Dial(proto, addr)
}

type tcpClient struct {
	client *C.struct_tcp_client
	buf    bytes.Buffer
	outbuf bytes.Buffer
	outMu  sync.Mutex
}

func (t *tcpClient) in(buf []byte) (n int, err error) {
	return t.buf.Write(buf)
}

type TunIO struct {
	client   *tcpClient
	destAddr string
	connOut  net.Conn
	quit     chan bool
	doFlush  chan bool
}

func (t *TunIO) TunnelID() C.uint32_t {
	return t.client.client.tunnel_id
}

func (t *TunIO) writer() error {
	for {
		select {
		case <-t.doFlush:
			if err := t.client.flush(); err != nil {
				return fmt.Errorf("Terminating writer abnormally.")
			}
		}
	}
	return nil
}

func (t *tcpClient) enqueue(chunk []byte) error {
	cchunk := C.CString(string(chunk))
	defer C.free(unsafe.Pointer(cchunk))

	for {
		err_t := C.tcp_write(t.client.pcb, unsafe.Pointer(cchunk), C.uint16_t(len(chunk)), 1)

		if err_t == C.ERR_OK {
			return nil
		}

		if err_t == C.ERR_MEM {
			// Could not enqueue anymore, let's flush and try again.
			err_t := C.tcp_output(t.client.pcb)
			if err_t == C.ERR_OK {
				continue
			}
			return fmt.Errorf("tcp_output: %d", int(err_t))
		}
	}

}

func (t *tcpClient) flush() error {

	for {
		blen := t.outbuf.Len()

		if blen > writeBufSize {
			blen = writeBufSize
		}

		if blen == 0 {
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

	err_t := C.tcp_output(t.client.pcb)
	if err_t != C.ERR_OK {
		return fmt.Errorf("tcp_output: %d", int(err_t))
	}

	return nil
}

func (t *TunIO) reader() error {
	for {
		data := make([]byte, readBufSize)
		n, err := t.connOut.Read(data)
		if err != nil {
			if err == io.EOF {
				C.client_close(t.client.client)
				return nil
			}
			return err
		}
		if n > 0 {
			t.client.outbuf.Write(data[0:n])
			t.doFlush <- true
		}
	}
	return nil
}

func NewTunnel(client *C.struct_tcp_client, d dialer) (*TunIO, error) {
	destAddr := C.dump_dest_addr(client)
	defer C.free(unsafe.Pointer(destAddr))

	t := &TunIO{
		client:   &tcpClient{client: client},
		destAddr: C.GoString(destAddr),
		quit:     make(chan bool),
		doFlush:  make(chan bool, 16),
	}

	conn, err := d("tcp", t.destAddr)
	if err != nil {
		return nil, err
	}

	t.connOut = conn

	go func() {
		if err := t.reader(); err != nil {
			log.Printf("t.reader: %q", err)
		}
	}()

	go func() {
		if err := t.writer(); err != nil {
			log.Printf("t.writer: %q", err)
		}
	}()

	return t, nil
}

//export goNewTunnel
func goNewTunnel(client *C.struct_tcp_client) C.uint32_t {
	newTunn, err := NewTunnel(client, Dialer)
	if err != nil {
		return 0
	}

	tunnelMu.Lock()
	var i uint32
	for {
		i = uint32(rand.Int31())
		if _, ok := tunnels[i]; !ok {
			break
		}
	}
	tunnels[i] = newTunn
	tunnelMu.Unlock()

	return C.uint32_t(i)
}

//export goTunnelWrite
func goTunnelWrite(tunno C.uint32_t, write *C.char, size C.size_t) C.int {
	tunnelMu.Lock()
	tunn, ok := tunnels[uint32(tunno)]
	defer tunnelMu.Unlock()

	if ok {
		size := int(size)
		buf := make([]byte, size)
		for i := 0; i < size; i++ {
			buf[i] = byte(C.charAt(write, C.int(i)))
		}
		if _, err := tunn.connOut.Write(buf); err == nil {
			return C.ERR_OK
		}
	}

	return C.ERR_ABRT
}

//export goTunnelDestroy
func goTunnelDestroy(tunno C.uint32_t) C.int {
	tunnelMu.Lock()
	defer tunnelMu.Unlock()

	tunn, ok := tunnels[uint32(tunno)]

	if ok {
		delete(tunnels, uint32(tunno))
		//tunn.quit <- true
		tunn.connOut.Close()
		return C.ERR_OK
	}

	return C.ERR_ABRT
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
