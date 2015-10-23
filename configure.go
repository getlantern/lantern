package tunio

import (
	"errors"
	"log"
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

var (
	debug = false
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
	times   map[uint32]int
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
	times = make(map[uint32]int)

	//rand.Seed(time.Now().UnixNano())
	rand.Seed(1)

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

type Status uint

const (
	StatusNew              Status = iota // 0
	StatusConnecting                     // 1
	StatusConnectionFailed               // 2
	StatusConnected                      // 3
	StatusReady                          // 4
	StatusProxying                       // 5
	StatusServerClosed                   // 6
	StatusClosing                        // 7
	StatusClosed                         // 8
)

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
