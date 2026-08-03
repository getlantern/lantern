package mobile

import (
	"errors"
	"testing"
	"time"

	"github.com/getlantern/radiance/ipc"
)

func TestGetClientDoesNotWaitForIPCLifecycleLock(t *testing.T) {
	want := &ipc.Client{}
	ipcClient.Store(want)
	t.Cleanup(func() {
		ipcClient.Store(nil)
	})

	ipcMu.Lock()
	defer ipcMu.Unlock()

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
	ipcMu.Lock()
	previousServer := ipcServer
	previousStarting := ipcStarting
	previousClosing := ipcClosing
	ipcServer = nil
	ipcStarting = true
	ipcClosing = false
	ipcMu.Unlock()
	t.Cleanup(func() {
		ipcMu.Lock()
		ipcServer = previousServer
		ipcStarting = previousStarting
		ipcClosing = previousClosing
		ipcMu.Unlock()
	})

	err := StartIPCServer(nil, nil)
	if !errors.Is(err, errIPCLifecycleBusy) {
		t.Fatalf("StartIPCServer() error = %v, want %v", err, errIPCLifecycleBusy)
	}
}
