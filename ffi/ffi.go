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
	"github.com/getlantern/radiance"
)

var (
	mu      sync.Mutex
	server  *radiance.Radiance
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

//export InitializeDartApi
// func InitializeDartApi(api unsafe.Pointer) {
// 	setupOnce.Do(func() {
// 		dart_api_dl.Init(api)
// 	})
// }

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		s, err := radiance.NewRadiance(baseDir)
		if err != nil {
			err = fmt.Errorf("unable to create radiance: %v", err)
			log.Error(err)
			return C.CString(err.Error())
		}
		server = s
	}
	if err := start(context.Background(), server); err != nil {
		err = fmt.Errorf("unable to start radiance: %v", err)
		log.Error(err)
		return C.CString(err.Error())
	}
	log.Debug("radiance started successfully")
	return nil
}

// stopVPN stops radiance if it is running.
//
//export stopVPN
func stopVPN() *C.char {
	log.Debug("stopVPN called")

	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		log.Debug("radiance is not running")
		return nil
	}

	if err := server.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop radiance: %v", err)
		log.Error(err)
		return C.CString(err.Error())
	}

	log.Debug("radiance stopped successfully")
	return nil
}

// isVPNConnected checks if radiance is running and connected.
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
