package mobile

import (
	"errors"
	"testing"
	"time"

	"github.com/getlantern/radiance/ipc"
)

func TestGetClientDoesNotWaitForIPCLifecycleLock(t *testing.T) {
	want := &ipc.Client{}
	previousClient := ipcClient.Swap(want)
	t.Cleanup(func() {
		ipcClient.Store(previousClient)
	})

	ipcLifecycle.mu.Lock()
	defer ipcLifecycle.mu.Unlock()

	result := make(chan *ipc.Client, 1)
	go func() {
		client, _ := getClient()
		result <- client
	}()

	select {
	case got := <-result:
		if got != want {
			t.Fatalf("getClient() = %p, want %p", got, want)
		}
	case <-time.After(time.Second):
		t.Fatal("getClient blocked on the IPC lifecycle lock")
	}
}

func TestStartIPCServerReportsLifecycleBusy(t *testing.T) {
	ipcLifecycle.mu.Lock()
	previousServer := ipcLifecycle.server
	previousStartState := ipcLifecycle.startState
	previousClosing := ipcLifecycle.closing
	ipcLifecycle.server = nil
	ipcLifecycle.startState = ipcStarting
	ipcLifecycle.closing = false
	ipcLifecycle.mu.Unlock()
	t.Cleanup(func() {
		ipcLifecycle.mu.Lock()
		ipcLifecycle.server = previousServer
		ipcLifecycle.startState = previousStartState
		ipcLifecycle.closing = previousClosing
		ipcLifecycle.mu.Unlock()
	})

	err := StartIPCServer(nil, nil)
	if !errors.Is(err, errIPCLifecycleBusy) {
		t.Fatalf("StartIPCServer() error = %v, want %v", err, errIPCLifecycleBusy)
	}
}

// The backend bootstrap now runs detached, so teardown can land while it is
// still going. close must not pull the backend out from under its own Start.
//
// The complementary invariant — that StartIPCServer returns without waiting for
// the bootstrap — is not reachable from a host unit test: ipc.Server binds
// /var/run/lantern/lanternd.sock on desktop builds and the path is not
// injectable from this package. It is pinned instead where the delay originates,
// in kindling's TestWithProxyless_SlowSearchDoesNotBlockConstruction.
func TestIPCResourcesCloseWaitsForBootstrap(t *testing.T) {
	t.Run("waits for a bootstrap that finishes", func(t *testing.T) {
		bootstrapped := make(chan struct{})
		closed := make(chan struct{})
		resources := ipcResources{bootstrapped: bootstrapped}

		go func() {
			defer close(closed)
			resources.close()
		}()

		select {
		case <-closed:
			t.Fatal("close returned while the bootstrap was still running")
		case <-time.After(100 * time.Millisecond):
		}

		close(bootstrapped)
		select {
		case <-closed:
		case <-time.After(time.Second):
			t.Fatal("close did not return after the bootstrap finished")
		}
	})

	t.Run("gives up on a wedged bootstrap", func(t *testing.T) {
		// A bootstrap wedged on a censored network must not hold teardown open;
		// iOS bounds stopTunnel too.
		resources := ipcResources{bootstrapped: make(chan struct{})}

		start := time.Now()
		resources.close()
		elapsed := time.Since(start)

		if elapsed < bootstrapCloseWait {
			t.Errorf("close returned after %v; want it to wait out %v first", elapsed, bootstrapCloseWait)
		}
		if elapsed > bootstrapCloseWait*3 {
			t.Errorf("close took %v; want it bounded near %v", elapsed, bootstrapCloseWait)
		}
	})

	t.Run("does not wait when there was no bootstrap", func(t *testing.T) {
		start := time.Now()
		ipcResources{}.close()
		if elapsed := time.Since(start); elapsed > time.Second {
			t.Errorf("close took %v with nothing to close; want it immediate", elapsed)
		}
	})
}
