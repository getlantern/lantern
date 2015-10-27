package tunio

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"golang.org/x/net/context"
)

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

var (
	reasonClientAbort = "Aborted by client."
)

//export goNewTunnel
// goNewTunnel is called from listener_accept_func. It creates a tunnel and
// assigns an unique ID to it.
func goNewTunnel(client *C.struct_tcp_client) C.uint32_t {
	var i uint32

	log.Printf("goNewTunnel (lookup)")

	t, err := NewTunnel(client, Dialer)
	if err != nil {
		log.Printf("Could not start tunnel: %q", err)
		return 0
	}

	// Looking for an unused ID to identify this tunnel.
	tunnelMu.Lock()
	defer tunnelMu.Unlock()

	for {
		i = uint32(rand.Int31())
		if _, ok := tunnels[i]; !ok {
			tunnels[i] = t
			t.SetStatus(StatusReady)
			return C.uint32_t(i)
		}
	}

	panic("reached.")
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
	t.ctx, t.ctxCancel = context.WithCancel(context.Background())

	writerOk := make(chan error)
	readerOk := make(chan error)

	go t.reader(readerOk)
	go t.writer(writerOk)

	<-writerOk
	<-readerOk

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

		//t.quit(fmt.Sprintf("got write error: %q", err))
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
	if !debug {
		return
	}
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

	if err := t.quit(reasonClientAbort); err != nil {
		return C.ERR_ABRT
	}

	return C.ERR_OK
}
