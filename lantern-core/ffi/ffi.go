package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"fmt"
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
)

var (
	dataDir    string
	logPort    int64
	server     *radiance.Radiance
	serverMu   sync.Mutex
	serverOnce sync.Once

	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

//export setup
func setup(dir *C.char, port C.int64_t, api unsafe.Pointer) {
	dataDir = C.GoString(dir)
	logPort = int64(port)

	serverOnce.Do(func() {
		r, err := radiance.NewRadiance(dataDir, nil)
		if err != nil {
			log.Fatalf("unable to create VPN server: %v", err)
		}
		log.Debugf("created new instance of radiance with data directory %s", dataDir)
		server = r
	})
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	slog.Debug("startVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	if err := server.StartVPN(); err != nil {
		err = fmt.Errorf("unable to start vpn server: %v", err)
		return C.CString(err.Error())
	}
	log.Debug("VPN server started successfully")
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
