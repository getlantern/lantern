package tunio

/*
#cgo CFLAGS: -c -std=gnu99 -DCGO=1 -DBADVPN_THREAD_SAFE=0 -DBADVPN_LINUX -DBADVPN_BREACTOR_BADVPN -D_GNU_SOURCE -DBADVPN_USE_SIGNALFD -DBADVPN_USE_EPOLL -DBADVPN_LITTLE_ENDIAN -Ibadvpn -Ibadvpn/lwip/src/include/ipv4 -Ibadvpn/lwip/src/include/ipv6 -Ibadvpn/lwip/src/include -Ibadvpn/lwip/custom
#cgo LDFLAGS: -lc -lrt -lpthread -static-libgcc -Wl,-Bstatic -ltun2io -L./lib/

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
	"log"
	"net"
	"sync"
	"unsafe"
)

var tunnels map[uint32]*TunIO
var tunnelMu sync.Mutex

const (
	minTunnID = 10
)

func init() {
	tunnels = make(map[uint32]*TunIO)
}

type dialer func(proto, addr string) (net.Conn, error)

var Dialer dialer

func dummyDialer(proto, addr string) (net.Conn, error) {
	return net.Dial(proto, addr)
}

type tcpClient struct {
	client *C.struct_tcp_client
	buf    bytes.Buffer
}

func (t *tcpClient) in(buf []byte) (n int, err error) {
	return t.buf.Write(buf)
}

func (t *tcpClient) out(buf []byte) (n int, err error) {
	n = len(buf)
	// TODO: error catch from tcp_write.
	fmt.Printf("writing to client: %q\n", string(buf))
	C.tcp_write(t.client.pcb, unsafe.Pointer(C.CString(string(buf))), C.uint16_t(n), 0)
	return n, nil
}

type TunIO struct {
	client   *tcpClient
	destAddr string
	connOut  net.Conn
}

func (t *TunIO) reader() error {
	for {
		data := make([]byte, 4096)
		n, err := t.connOut.Read(data)
		if err != nil {
			return err
		}
		t.client.out(data[0:n])
	}
	return nil
}

func NewTunnel(client *C.struct_tcp_client, d dialer) (*TunIO, error) {
	destAddr := C.dump_dest_addr(client)
	t := &TunIO{
		client:   &tcpClient{client: client},
		destAddr: C.GoString(destAddr),
	}
	log.Printf("Opening tunnel to %q...", t.destAddr)
	conn, err := d("tcp", t.destAddr)
	if err != nil {
		return nil, err
	}
	t.connOut = conn
	go t.reader()
	C.free(unsafe.Pointer(destAddr))
	return t, nil
}

//export goNewTunnel
func goNewTunnel(client *C.struct_tcp_client) C.uint32_t {
	newTunn, err := NewTunnel(client, Dialer)
	if err != nil {
		return 0
	}

	tunnelMu.Lock()
	// TODO: Use https://golang.org/pkg/math/rand/#Int31n
	var i uint32
	for i = minTunnID; ; i++ {
		if _, ok := tunnels[i]; !ok {
			break
		}
	}
	tunnels[i] = newTunn
	tunnelMu.Unlock()

	log.Printf("%d: goNewTunnel", i)

	return C.uint32_t(i)
}

//export goTunnelWrite
func goTunnelWrite(tunno C.uint32_t, write *C.char, size C.size_t) C.int {
	log.Printf("%d: goTunnelWrite", int(tunno))
	tunnelMu.Lock()
	tunn := tunnels[uint32(tunno)]
	tunnelMu.Unlock()

	if tunn != nil {
		buf := make([]byte, 0, size)
		for i := 0; i < int(size); i++ {
			buf = append(buf, byte(C.charAt(write, C.int(i))))
		}
		if _, err := tunn.connOut.Write(buf); err != nil {
			return C.ERR_OK
		}
	}

	return C.ERR_ABRT
}

//export goTunnelDestroy
func goTunnelDestroy(tunno C.uint32_t) C.int {
	log.Printf("%d: goTunnelDestroy", int(tunno))
	tunnelMu.Lock()
	defer tunnelMu.Unlock()
	tunn, ok := tunnels[uint32(tunno)]
	if ok {
		tunn.connOut.Close()
		delete(tunnels, uint32(tunno))
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
	if C.configure(C.CString(tundev), C.CString(ipaddr), C.CString(netmask)) != C.ERR_OK {
		return errors.New("Failed to configure device.")
	}
	return nil
}
