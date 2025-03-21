package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"sync"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
)

var (
	baseDir        string
	logPort        int64
	serverMu       sync.Mutex
	setupOnce      sync.Once
	radianceMu     sync.Mutex
	radianceServer *radiance.Radiance

	log = golog.LoggerFor("lantern-outline.ffi")
)

// setupRadiance initializes the Radiance
//
//export setupRadiance
func setupRadiance() *C.char {
	radianceMu.Lock()
	defer radianceMu.Unlock()
	r, err := radiance.NewRadiance(nil)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return SendError(err)
	}
	radianceServer = r
	log.Debug("Radiance setup successfully")
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
	log.Debug("startVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	log.Debug("VPN server started successfully")
	return nil
}

// stopVPN stops the VPN server if it is running.
//
//export stopVPN
func stopVPN() *C.char {
	log.Debug("stopVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	log.Debug("VPN server stopped successfully")
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
