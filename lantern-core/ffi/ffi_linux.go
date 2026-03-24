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
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
)

const (
	linuxServiceName = "lanternd"
	linuxSocketPath  = "/var/run/lantern/lanternd.sock"
)

var (
	linuxClient       = ipc.NewClient()
	linuxStatusOnce   sync.Once
	linuxLastStatusMu sync.Mutex
	linuxLastStatus   string
)

func requireLanternServiceAvailable() error {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()

	_, err := linuxClient.VPNStatus(ctx)
	if err == nil {
		return nil
	}

	if diag := systemdDiag(linuxServiceName); diag != "" {
		return fmt.Errorf("%s not reachable (%s): %s", linuxServiceName, linuxSocketPath, diag)
	}
	return fmt.Errorf("%s not reachable (%s)", linuxServiceName, linuxSocketPath)
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

func startLinuxStatusPoller() {
	linuxStatusOnce.Do(func() {
		go func() {
			t := time.NewTicker(500 * time.Millisecond)
			defer t.Stop()

			for range t.C {
				if statusPort == 0 {
					continue
				}

				ctx, cancel := context.WithTimeout(context.Background(), 400*time.Millisecond)
				status, err := linuxClient.VPNStatus(ctx)
				cancel()

				ui := mapVPNStatusToUI(status, err)

				linuxLastStatusMu.Lock()
				changed := ui != linuxLastStatus
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

func normalizeIPCGroup(locationType string) string {
	switch locationType {
	case "", "auto", "auto-all":
		return "all"
	case "privateServer":
		return string(servers.SGUser)
	case "lanternLocation":
		return string(servers.SGLantern)
	default:
		return locationType
	}
}

//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	startLinuxStatusPoller()
	sendStatusToPort(Connecting)

	if err := requireLanternServiceAvailable(); err != nil {
		sendStatusToPort(Error)
		return C.CString(err.Error())
	}

	ctx := context.Background()
	if err := linuxClient.ConnectVPN(ctx, ""); err != nil &&
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

	if err := linuxClient.DisconnectVPN(ctx); err != nil {
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
	_ = normalizeIPCGroup(locationType)

	startLinuxStatusPoller()

	if err := requireLanternServiceAvailable(); err != nil {
		return SendError(err)
	}

	ctx := context.Background()
	connectTag := tag
	if connectTag == "" {
		connectTag = "" // auto-select
	}
	if err := linuxClient.ConnectVPN(ctx, connectTag); err != nil &&
		!errors.Is(err, ipc.ErrServiceIsNotReady) {
		if errors.Is(err, ipc.ErrIPCNotRunning) {
			if diagErr := requireLanternServiceAvailable(); diagErr != nil {
				return SendError(diagErr)
			}
		}
		return SendError(fmt.Errorf("start service failed: %w", err))
	}

	return C.CString("ok")
}

//export isVPNConnected
func isVPNConnected() C.int {
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Millisecond)
	defer cancel()

	status, err := linuxClient.VPNStatus(ctx)
	ui := mapVPNStatusToUI(status, err)

	sendStatusToPort(VPNStatus(ui))

	if ui == string(Connected) {
		return 1
	}
	return 0
}
