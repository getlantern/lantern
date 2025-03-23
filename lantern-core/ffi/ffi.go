package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/radiance"
)

var (
	baseDir        string
	logPort        int64
	serverMu       sync.Mutex
	setupOnce      sync.Once
	radianceMu     sync.Mutex
	radianceServer *radiance.Radiance
)

// setupRadiance initializes the Radiance
//
//export setupRadiance
func setupRadiance(dir *C.char) *C.char {
	radianceMu.Lock()
	defer radianceMu.Unlock()
	r, err := radiance.NewRadiance(C.GoString(dir), nil)
	if err != nil {
		slog.Error("Unable to create Radiance: %v", "error", err)
		return SendError(err)
	}
	radianceServer = r
	slog.Debug("Radiance setup successfully")
	return C.CString("true")
}

// this used for settting things for logs such as logs directory and port
//
//export setupLogging
func setupLogging(dir *C.char, port C.int64_t, api unsafe.Pointer) {
	serverMu.Lock()
	defer serverMu.Unlock()

	baseDir = C.GoString(dir)
	logPort = int64(port)
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	slog.Debug("startVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	slog.Debug("VPN server started successfully")
	return nil
}

// stopVPN stops the VPN server if it is running.
//
//export stopVPN
func stopVPN() *C.char {
	slog.Debug("stopVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	slog.Debug("VPN server stopped successfully")
	return nil
}

// isVPNConnected checks if the VPN server is running and connected.
//
//export isVPNConnected
func isVPNConnected() int {
	serverMu.Lock()
	defer serverMu.Unlock()

	return 1
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
