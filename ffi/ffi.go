package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"context"
	"fmt"
	"sync"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/dart_api_dl"
)

var (
	mu      sync.Mutex
	baseDir string

	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

//export setup
func setup(dir *C.char, port C.int64_t, api unsafe.Pointer) {
	mu.Lock()
	defer mu.Unlock()
	baseDir = C.GoString(dir)
	logPort = int64(port)

	setupOnce.Do(func() {
		dart_api_dl.Init(api)
		configureLogging(baseDir, logPort)
	})
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	mu.Lock()
	defer mu.Unlock()

	if err := start(context.Background(), baseDir); err != nil {
		err = fmt.Errorf("unable to start VPN server: %v", err)
		log.Error(err)
		return C.CString(err.Error())
	}
	log.Debug("VPN server started successfully")
	return nil
}

// stopVPN stops the VPN server if it is running.
//
//export stopVPN
func stopVPN() *C.char {
	log.Debug("stopVPN called")

	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		log.Debug("VPN server is not running")
		return nil
	}

	if err := server.Stop(); err != nil {
		err = fmt.Errorf("unable to stop VPN server: %v", err)
		log.Error(err)
		return C.CString(err.Error())
	}

	log.Debug("VPN server stopped successfully")
	return nil
}

// isVPNConnected checks if the VPN server is running and connected.
//
//export isVPNConnected
func isVPNConnected() int {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		return 0
	}

	return 1
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
