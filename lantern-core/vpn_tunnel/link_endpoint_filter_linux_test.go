//go:build with_gvisor && linux

package vpn_tunnel_test

import (
	"testing"
	"time"

	"github.com/sagernet/gvisor/pkg/tcpip/link/fdbased"
	tun "github.com/sagernet/sing-tun"
	"golang.org/x/sys/unix"
)

// Exercise Android's gVisor fd reader with an unprivileged socket pair.
func TestLinkEndpointFilterStopsFDReader(t *testing.T) {
	fds, err := unix.Socketpair(unix.AF_UNIX, unix.SOCK_DGRAM|unix.SOCK_CLOEXEC, 0)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = unix.Close(fds[0])
		_ = unix.Close(fds[1])
	})
	endpoint, err := fdbased.New(&fdbased.Options{
		FDs: []int{fds[0]}, MTU: 1500, ProcessorsPerChannel: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	// Bypass the filter so a broken detach cannot leak its polling reader.
	t.Cleanup(func() {
		done := make(chan struct{})
		go func() {
			endpoint.Attach(nil)
			endpoint.Wait()
			close(done)
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Error("direct endpoint detach did not clean up the fd reader")
		}
	})

	dispatcher := make(packetDispatcher, 1)
	filter := &tun.LinkEndpointFilter{LinkEndpoint: endpoint}
	filter.Attach(dispatcher)
	// Prove the reader started by delivering a minimal IPv4 UDP datagram.
	packet := []byte{
		0x45, 0, 0, 28, 0, 0, 0, 0, 64, 17, 0, 0, 8, 8, 8, 8, 1, 1, 1, 1,
		0x12, 0x34, 0x56, 0x78, 0, 8, 0, 0,
	}
	if _, err := unix.Write(fds[1], packet); err != nil {
		t.Fatal(err)
	}
	select {
	case <-dispatcher:
	case <-time.After(5 * time.Second):
		t.Fatal("fd reader did not deliver the test datagram")
	}

	done := make(chan struct{})
	go func() {
		filter.Attach(nil)
		endpoint.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("filter detach left the fd reader running; TUN shutdown cannot release its kernel reference")
	}
	if endpoint.IsAttached() {
		t.Fatal("filter detach left the underlying endpoint attached")
	}
}
