package vpn_tunnel

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/getlantern/radiance/vpn"
)

type blockingClient struct {
	statusCalls  atomic.Int32
	connectCalls atomic.Int32
	statusCalled chan struct{}
	release      chan struct{}
	releaseOnce  sync.Once
}

func (c *blockingClient) VPNStatus(ctx context.Context) (vpn.VPNStatus, error) {
	call := c.statusCalls.Add(1)
	c.statusCalled <- struct{}{}
	if call == 1 {
		select {
		case <-c.release:
		case <-ctx.Done():
			return vpn.Disconnected, ctx.Err()
		}
	}
	return vpn.Disconnected, nil
}

func (c *blockingClient) ConnectVPN(context.Context, string) error {
	c.connectCalls.Add(1)
	return nil
}

func (c *blockingClient) SelectServer(context.Context, string) error {
	return nil
}

func (c *blockingClient) unblock() {
	c.releaseOnce.Do(func() { close(c.release) })
}

func TestConnectToServerSerializesRequests(t *testing.T) {
	client := &blockingClient{
		statusCalled: make(chan struct{}, 2),
		release:      make(chan struct{}),
	}
	t.Cleanup(client.unblock)

	firstDone := make(chan error, 1)
	go func() {
		firstDone <- connectToServer(context.Background(), client, "first")
	}()
	waitForStatusCall(t, client.statusCalled)

	secondDone := make(chan error, 1)
	secondCtx, cancelSecond := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancelSecond()
	go func() {
		secondDone <- connectToServer(secondCtx, client, "second")
	}()

	select {
	case <-client.statusCalled:
		t.Fatal("second request entered while the first was still running")
	case <-time.After(100 * time.Millisecond):
	}

	if err := waitForError(t, secondDone); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("second request error = %v, want %v", err, context.DeadlineExceeded)
	}

	client.unblock()
	waitForResult(t, firstDone)

	if err := connectToServer(context.Background(), client, "third"); err != nil {
		t.Fatal(err)
	}
	if got := client.connectCalls.Load(); got != 2 {
		t.Fatalf("ConnectVPN called %d times, want 2", got)
	}
}

func waitForStatusCall(t *testing.T, called <-chan struct{}) {
	t.Helper()
	select {
	case <-called:
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for VPNStatus")
	}
}

func waitForResult(t *testing.T, result <-chan error) {
	t.Helper()
	if err := waitForError(t, result); err != nil {
		t.Fatal(err)
	}
}

func waitForError(t *testing.T, result <-chan error) error {
	t.Helper()
	select {
	case err := <-result:
		return err
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for connect request")
		return nil
	}
}
