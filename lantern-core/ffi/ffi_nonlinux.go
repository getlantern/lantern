//go:build !linux && !android && !ios && !macos

package main

/*
#include <stdlib.h>
#include "stdint.h"
*/
import "C"

import (
	"fmt"
	"log/slog"

	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	slog.Debug("startVPN called (non-linux)")
	sendStatusToPort(Connecting)
	if err := vpn_tunnel.StartVPN(c.Client()); err != nil {
		sendStatusToPort(Disconnected)
		return C.CString(fmt.Sprintf("unable to start vpn server: %v", err))
	}
	sendStatusToPort(Connected)
	return C.CString("ok")
}

//export stopVPN
func stopVPN() *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	slog.Debug("stopVPN called (non-linux)")
	sendStatusToPort(Disconnecting)
	if err := vpn_tunnel.StopVPN(c.Client()); err != nil {
		sendStatusToPort(Connected)
		return C.CString(fmt.Sprintf("unable to stop vpn server: %v", err))
	}
	sendStatusToPort(Disconnected)
	return C.CString("ok")
}

//export connectToServer
func connectToServer(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	locationType := C.GoString(_location)
	tag := C.GoString(_tag)

	if err := vpn_tunnel.ConnectToServer(c.Client(), locationType, tag); err != nil {
		return SendError(fmt.Errorf("error setting private server: %v", err))
	}
	slog.Debug("connectToServer OK (non-linux)", "tag", tag)
	return C.CString("ok")
}

//export isVPNConnected
func isVPNConnected() C.int {
	c, errStr := requireCore()
	if errStr != nil {
		return 0
	}
	connected := vpn_tunnel.IsVPNRunning(c.Client())
	if connected {
		sendStatusToPort(Connected)
		return 1
	}
	sendStatusToPort(Disconnected)
	return 0
}
