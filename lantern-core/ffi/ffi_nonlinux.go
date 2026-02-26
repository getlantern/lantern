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

	"github.com/getlantern/lantern/lantern-core/utils"
	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	slog.Debug("startVPN called (non-linux)")
	sendStatusToPort(Connecting)
	if err := vpn_tunnel.StartVPN(nil, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	}); err != nil {
		err = fmt.Errorf("unable to start vpn server: %v", err)
		sendStatusToPort(Disconnected)
		return C.CString(err.Error())
	}
	sendStatusToPort(Connected)
	return C.CString("ok")
}

//export stopVPN
func stopVPN() *C.char {
	slog.Debug("stopVPN called (non-linux)")
	sendStatusToPort(Disconnecting)
	if err := vpn_tunnel.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop vpn server: %v", err)
		sendStatusToPort(Connected)
		return C.CString(err.Error())
	}
	sendStatusToPort(Disconnected)
	return C.CString("ok")
}

//export connectToServer
func connectToServer(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	locationType := C.GoString(_location)
	tag := C.GoString(_tag)

	if err := vpn_tunnel.ConnectToServer(locationType, tag, nil, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	}); err != nil {
		return SendError(fmt.Errorf("error setting private server: %v", err))
	}
	slog.Debug("connectToServer OK (non-linux)", "tag", tag)
	return C.CString("ok")
}

//export isVPNConnected
func isVPNConnected() C.int {
	connected := vpn_tunnel.IsVPNRunning()
	if connected {
		sendStatusToPort(Connected)
		return 1
	}
	sendStatusToPort(Disconnected)
	return 0
}
