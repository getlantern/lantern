package vpn

import (
	"context"
	"io"
	"testing"

	"github.com/getlantern/lantern-outline/lantern-core/dialer"
	"github.com/stretchr/testify/require"
)

// fakeTunnel is a simple fake that implements the tunnel interface.
type fakeTunnel struct {
	isClosed bool
	writeErr error
}

func (ft *fakeTunnel) Start(d dialer.Dialer, tunWriter io.WriteCloser) error {
	return nil
}
func (ft *fakeTunnel) Write(data []byte) (int, error) {
	if ft.writeErr != nil {
		return 0, ft.writeErr
	}
	return len(data), nil
}
func (ft *fakeTunnel) Close() error {
	ft.isClosed = true
	return nil
}

func newDefaultOpts() *Opts {
	return &Opts{
		Address: "127.0.0.1:0",
	}
}

func newTestServer(t *testing.T) *iOSVPN {
	ss, err := NewIOSVPNServer(newDefaultOpts())
	require.NoError(t, err)
	return ss.(*iOSVPN)
}

// Test that ProcessInboundPacket writes data via the tunnel.
func TestServer_ProcessInboundPacket(t *testing.T) {
	server := newTestServer(t)
	// Replace the tunnel with the fake.
	fake := &fakeTunnel{}
	server.tunnel = fake

	data := []byte("packet data")
	err := server.ProcessInboundPacket(data, len(data))
	if err != nil {
		t.Fatalf("ProcessInboundPacket returned error: %v", err)
	}
}

func TestVPNServer_Stop(t *testing.T) {
	server := newTestServer(t)
	fake := &fakeTunnel{}
	server.tunnel = fake

	server.setConnected(true)

	err := server.Stop()
	if err != nil {
		t.Fatalf("Stop returned error: %v", err)
	}
	if server.IsVPNConnected() {
		t.Error("VPN should be disconnected after Stop")
	}
	if !fake.isClosed {
		t.Error("Tunnel was not closed on Stop")
	}
}
func TestVPNServer_StartAlreadyRunning(t *testing.T) {
	server := newTestServer(t)
	server.setConnected(true)
	err := server.Start(context.Background())
	if err == nil {
		t.Error("expected error when starting VPN that is already running")
	}
}
