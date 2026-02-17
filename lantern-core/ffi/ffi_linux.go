//go:build linux && !android

package main

/*
#include <stdlib.h>
#include "stdint.h"
*/
import "C"

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unsafe"

	"github.com/getlantern/radiance/vpn/ipc"
)

const linuxDefaultSock = "/var/run/lantern/lantern.sock"

var (
	linuxStatusOnce   sync.Once
	linuxLastStatusMu sync.Mutex
	linuxLastStatus   string
)

// systemd manages the daemon; just verify IPC availability.
func requireLanternSvcAvailable() error {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()

	st, err := ipc.GetStatus(ctx)
	if err == nil && st != "" {
		return nil
	}

	if diag := systemdDiag("lantern"); diag != "" {
		return fmt.Errorf("lanternd not reachable (%s): %s", linuxDefaultSock, diag)
	}
	return fmt.Errorf("lanternd not reachable (%s)", linuxDefaultSock)
}

func systemdDiag(unit string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 250*time.Millisecond)
	defer cancel()

	u := unit
	if filepath.Ext(u) == "" {
		u = unit + ".service"
	}

	out, err := exec.CommandContext(ctx, "systemctl", "is-active", u).CombinedOutput()
	if err != nil && len(out) == 0 {
		return ""
	}

	switch strings.TrimSpace(string(out)) {
	case "active":
		return "systemd says active, but IPC isn't responding"
	case "inactive":
		return "systemd says inactive"
	case "failed":
		return "systemd says failed"
	case "activating":
		return "systemd says activating"
	case "deactivating":
		return "systemd says deactivating"
	default:
		return strings.TrimSpace(string(out))
	}
}

// Poll IPC status and forward changes to Dart.
func startLinuxStatusPoller(_dataDir string) {
	linuxStatusOnce.Do(func() {
		go func() {
			t := time.NewTicker(500 * time.Millisecond)
			defer t.Stop()

			for range t.C {
				if statusPort == 0 {
					continue
				}

				ctx, cancel := context.WithTimeout(context.Background(), 400*time.Millisecond)
				st, err := ipc.GetStatus(ctx)
				cancel()

				ui := mapIPCStateToUIStatus(st, err)

				linuxLastStatusMu.Lock()
				changed := (ui != linuxLastStatus)
				if changed {
					linuxLastStatus = ui
				}
				linuxLastStatusMu.Unlock()

				if changed {
					sendStatusToPort(VPNStatus(ui))
				}
			}
		}()
	})
}

func mapIPCStateToUIStatus(state string, err error) string {
	if err != nil {
		return string(Disconnected)
	}
	switch state {
	case ipc.StatusRunning:
		return string(Connected)
	case ipc.StatusConnecting, ipc.StatusInitializing:
		return string(Connecting)
	case ipc.StatusClosing:
		return string(Disconnecting)
	case ipc.StatusClosed:
		return string(Disconnected)
	default:
		return string(Disconnected)
	}
}

// Linux VPN function overrides.

//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	dataDir := C.GoString(_dataDir)

	startLinuxStatusPoller(dataDir)
	sendStatusToPort(Connecting)

	if err := requireLanternSvcAvailable(); err != nil {
		sendStatusToPort(Error)
		return C.CString(err.Error())
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := ipc.StartService(ctx, "", ""); err != nil {
		if !errors.Is(err, ipc.ErrServiceIsNotReady) {
			sendStatusToPort(Error)
			return C.CString(fmt.Sprintf("start service failed: %v", err))
		}
	}

	sendStatusToPort(Connected)
	return C.CString("ok")
}

//export stopVPN
func stopVPN() *C.char {
	sendStatusToPort(Disconnecting)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := ipc.StopService(ctx); err != nil {
		sendStatusToPort(Disconnected)
		return C.CString(fmt.Sprintf("stop service failed: %v", err))
	}

	sendStatusToPort(Disconnected)
	return C.CString("ok")
}

//export connectToServer
func connectToServer(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	locationType := C.GoString(_location)
	tag := C.GoString(_tag)
	dataDir := C.GoString(_dataDir)

	startLinuxStatusPoller(dataDir)

	if err := requireLanternSvcAvailable(); err != nil {
		return SendError(err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	if err := ipc.StartService(ctx, "", ""); err != nil && !errors.Is(err, ipc.ErrServiceIsNotReady) {
		return SendError(fmt.Errorf("start service failed: %w", err))
	}

	if locationType == "auto" || tag == "" {
		return C.CString("ok")
	}

	mode, err := ipc.GetClashMode(ctx)
	if err != nil || mode == "" {
		mode = "global"
	}

	if err := ipc.SelectOutbound(ctx, mode, tag); err != nil {
		return SendError(fmt.Errorf("select outbound failed: %w", err))
	}

	return C.CString("ok")
}

//export isVPNConnected
func isVPNConnected() C.int {
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Millisecond)
	defer cancel()

	st, err := ipc.GetStatus(ctx)
	ui := mapIPCStateToUIStatus(st, err)

	sendStatusToPort(VPNStatus(ui))

	if ui == string(Connected) {
		return 1
	}
	return 0
}

func freeGoCString(p unsafe.Pointer) {
	C.free(p)
}

func linuxDebugToStatusPort(msg any) {
	if statusPort == 0 {
		return
	}
	b, _ := json.Marshal(msg)
	slog.Debug("linuxDebugToStatusPort", "msg", string(b))
}
