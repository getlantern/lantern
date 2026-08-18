package mobile

import (
	"errors"
	"testing"
	"time"

	"github.com/getlantern/radiance/backend"
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

// withCleanIPCLifecycle isolates a test from whatever the package-level
// lifecycle currently holds, and restores it afterwards.
func withCleanIPCLifecycle(t *testing.T) {
	t.Helper()
	ipcLifecycle.mu.Lock()
	// Field by field: ipcLifecycleState holds a mutex, so copying the struct
	// would copy the lock with it.
	prevServer, prevBackend := ipcLifecycle.server, ipcLifecycle.backend
	prevBootstrapped := ipcLifecycle.bootstrapped
	prevStartState, prevClosing := ipcLifecycle.startState, ipcLifecycle.closing
	prevGeneration := ipcLifecycle.generation
	ipcLifecycle.server = nil
	ipcLifecycle.backend = nil
	ipcLifecycle.bootstrapped = nil
	ipcLifecycle.mu.Unlock()
	t.Cleanup(func() {
		ipcLifecycle.mu.Lock()
		ipcLifecycle.server, ipcLifecycle.backend = prevServer, prevBackend
		ipcLifecycle.bootstrapped = prevBootstrapped
		ipcLifecycle.startState, ipcLifecycle.closing = prevStartState, prevClosing
		ipcLifecycle.generation = prevGeneration
		ipcLifecycle.mu.Unlock()
	})
}

// stubBootstrap swaps the detached LocalBackend.Start for one the test drives.
// The returned channel receives once per launch.
func stubBootstrap(t *testing.T, done <-chan struct{}) <-chan struct{} {
	t.Helper()
	launched := make(chan struct{}, 4)
	orig := bootstrapBackend
	bootstrapBackend = func(*backend.LocalBackend) <-chan struct{} {
		launched <- struct{}{}
		return done
	}
	t.Cleanup(func() { bootstrapBackend = orig })
	return launched
}

// A startup that lost its race is torn down immediately, so it must never have
// launched a bootstrap: Start would then be running against a backend that
// close is already tearing down, and LocalBackend.Close's peerWG.Wait cannot
// see a peerWG.Add that has not happened yet.
func TestPublishIPCResourcesCancelledStartupLaunchesNoBootstrap(t *testing.T) {
	withCleanIPCLifecycle(t)
	launched := stubBootstrap(t, nil)

	ipcLifecycle.mu.Lock()
	generation := ipcLifecycle.generation
	ipcLifecycle.generation++ // CloseIPCServer ran during setup
	ipcLifecycle.mu.Unlock()

	err := publishIPCResources(generation, ipcResources{})
	if !errors.Is(err, errIPCStartCanceled) {
		t.Fatalf("publishIPCResources() error = %v, want %v", err, errIPCStartCanceled)
	}
	if len(launched) != 0 {
		t.Errorf("launched %d bootstraps for a cancelled startup; want 0", len(launched))
	}
}

// The published path is the only one that starts a bootstrap, and it has to
// keep the handle so teardown can wait on it.
func TestPublishIPCResourcesLaunchesBootstrapAndKeepsHandle(t *testing.T) {
	withCleanIPCLifecycle(t)
	done := make(chan struct{})
	close(done)
	launched := stubBootstrap(t, done)

	ipcLifecycle.mu.Lock()
	generation := ipcLifecycle.generation
	ipcLifecycle.mu.Unlock()

	if err := publishIPCResources(generation, ipcResources{}); err != nil {
		t.Fatalf("publishIPCResources() error = %v", err)
	}
	if len(launched) != 1 {
		t.Errorf("launched %d bootstraps; want exactly 1", len(launched))
	}

	ipcLifecycle.mu.Lock()
	held := ipcLifecycle.bootstrapped
	ipcLifecycle.mu.Unlock()
	if held == nil {
		t.Error("lifecycle did not keep the bootstrap handle; teardown could not wait on it")
	}
}

// close must not tear the backend down while Start is still running. The wait
// is unbounded on purpose — see the comment on ipcResources.close.
func TestIPCResourcesCloseWaitsForBootstrap(t *testing.T) {
	t.Run("waits for a live bootstrap", func(t *testing.T) {
		bootstrapped := make(chan struct{})
		closed := make(chan struct{})
		go func() {
			defer close(closed)
			ipcResources{bootstrapped: bootstrapped}.close()
		}()

		select {
		case <-closed:
			t.Fatal("close returned while the bootstrap was still running")
		case <-time.After(100 * time.Millisecond):
		}

		close(bootstrapped)
		select {
		case <-closed:
		case <-time.After(5 * time.Second):
			t.Fatal("close did not return after the bootstrap finished")
		}
	})

	t.Run("does not wait when no bootstrap was launched", func(t *testing.T) {
		done := make(chan struct{})
		go func() {
			defer close(done)
			ipcResources{}.close()
		}()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatal("close blocked with no bootstrap to wait for")
		}
	})
}
