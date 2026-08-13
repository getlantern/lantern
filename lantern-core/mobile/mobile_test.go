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
