//go:build linux && !android && !ios && !macos

package main

/*
#include <stdlib.h>
#include "stdint.h"
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/radiance/ipc"
	"github.com/getlantern/radiance/vpn"
)

const (
	linuxServiceName = "lanternd"
)

var (
	ipcClient         = ipc.NewClient()
	linuxStatusOnce   sync.Once
	linuxLastStatusMu sync.Mutex
	linuxLastStatus   string
)

func requireLanternServiceAvailable() error {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()

	if _, err := ipcClient.VPNStatus(ctx); err == nil {
		return nil
	}

	if diag := systemdDiag(linuxServiceName); diag != "" {
		return fmt.Errorf("%s not reachable: %s", linuxServiceName, diag)
	}
	return fmt.Errorf("%s not reachable", linuxServiceName)
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
		return "systemd says active, but IPC is not responding"
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

func startLinuxStatusListener() {
	linuxStatusOnce.Do(func() {
		go func() {
			t := time.NewTicker(500 * time.Millisecond)
			defer t.Stop()

			for range t.C {
				if statusPort == 0 {
					continue
				}
				ipcClient.VPNStatusEvents(context.Background(), func(status vpn.StatusUpdateEvent) {
					var err error
					if status.Error != "" {
						err = errors.New(status.Error)
					}
					ui := mapVPNStatusToUI(status.Status, err)

					linuxLastStatusMu.Lock()
					changed := ui != linuxLastStatus
					if changed {
						linuxLastStatus = ui
					}
					linuxLastStatusMu.Unlock()

					if changed {
						sendStatusToPort(VPNStatus(ui))
					}
				})
			}
		}()
	})
}

func mapVPNStatusToUI(status vpn.VPNStatus, err error) string {
	if err != nil {
		return string(Disconnected)
	}
	switch status {
	case vpn.Connected:
		return string(Connected)
	case vpn.Connecting:
		return string(Connecting)
	case vpn.Disconnecting:
		return string(Disconnecting)
	case vpn.Disconnected:
		return string(Disconnected)
	default:
		return string(Disconnected)
	}
}

//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	startLinuxStatusListener()
	sendStatusToPort(Connecting)

	if err := requireLanternServiceAvailable(); err != nil {
		sendStatusToPort(Error)
		return C.CString(err.Error())
	}

	ctx := context.Background()
	if err := ipcClient.ConnectVPN(ctx, ""); err != nil &&
		!errors.Is(err, ipc.ErrServiceIsNotReady) {
		sendStatusToPort(Error)
		if errors.Is(err, ipc.ErrIPCNotRunning) {
			if diagErr := requireLanternServiceAvailable(); diagErr != nil {
				return C.CString(diagErr.Error())
			}
		}
		return C.CString(fmt.Sprintf("start service failed: %v", err))
	}

	sendStatusToPort(Connected)
	return C.CString("ok")
}

//export stopVPN
func stopVPN() *C.char {
	sendStatusToPort(Disconnecting)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := ipcClient.DisconnectVPN(ctx); err != nil {
		sendStatusToPort(Disconnected)
		return C.CString(fmt.Sprintf("stop service failed: %v", err))
	}

	sendStatusToPort(Disconnected)
	return C.CString("ok")
}

//export connectToServer
func connectToServer(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	startLinuxStatusListener()
	sendStatusToPort(Connecting)

	if err := requireLanternServiceAvailable(); err != nil {
		sendStatusToPort(Error)
		return SendError(err)
	}

	tag := C.GoString(_tag)
	ctx := context.Background()
	if err := ipcClient.ConnectVPN(ctx, tag); err != nil &&
		!errors.Is(err, ipc.ErrServiceIsNotReady) {
		sendStatusToPort(Error)
		if errors.Is(err, ipc.ErrIPCNotRunning) {
			if diagErr := requireLanternServiceAvailable(); diagErr != nil {
				return SendError(diagErr)
			}
		}
		return SendError(fmt.Errorf("start service failed: %w", err))
	}

	sendStatusToPort(Connected)
	return C.CString("ok")
}

//export isVPNConnected
func isVPNConnected() C.int {
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Millisecond)
	defer cancel()

	status, err := ipcClient.VPNStatus(ctx)
	ui := mapVPNStatusToUI(status, err)

	sendStatusToPort(VPNStatus(ui))

	if ui == string(Connected) {
		return 1
	}
	return 0
}
