package tunio

import (
	"errors"
	"math/rand"
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

type dialer func(proto, addr string) (net.Conn, error)

var (
	debug = true
)

var (
	errBufferIsFull = errors.New("Buffer is full.")
)

const (
	readBufSize = 1024 * 64
)

var (
	udpGwServerAddress string
)

var ioTimeout = time.Second * 30

var (
	tunnels  map[uint32]*TunIO
	tunnelMu sync.Mutex
)

func init() {
	tunnels = make(map[uint32]*TunIO)
	//rand.Seed(time.Now().UnixNano())
	rand.Seed(1)
	udpgwInit()
}

var Dialer dialer

func dummyDialer(proto, addr string) (net.Conn, error) {
	return net.Dial(proto, addr)
}

type Status uint

const (
	StatusNew              Status = iota // 0
	StatusConnecting                     // 1
	StatusConnectionFailed               // 2
	StatusConnected                      // 3
	StatusReady                          // 4
	StatusProxying                       // 5
	StatusClosing                        // 6
	StatusClosed                         // 7
)

// Configure sets up the tundevice, this is equivalent to the badvpn-tun2socks
// configuration, except for the --socks-server-addr.
func Configure(tundev, ipaddr, netmask, udpgw string, d dialer) error {
	if d == nil {
		d = dummyDialer
	}

	Dialer = d
	udpGwServerAddress = udpgw

	ctundev := C.CString(tundev)
	cipaddr := C.CString(ipaddr)
	cnetmask := C.CString(netmask)
	cudpgw_addr := C.CString(udpgw)

	defer func() {
		C.free(unsafe.Pointer(ctundev))
		C.free(unsafe.Pointer(cipaddr))
		C.free(unsafe.Pointer(cnetmask))
		C.free(unsafe.Pointer(cudpgw_addr))
	}()

	if err_t := C.configure(ctundev, cipaddr, cnetmask, cudpgw_addr); err_t != C.ERR_OK {
		return errors.New("Failed to configure device.")
	}

	return nil
}
