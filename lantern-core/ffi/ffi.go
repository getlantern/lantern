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
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/lantern-outline/lantern-core/empty"
	"github.com/getlantern/lantern-outline/lantern-core/vpn"
	"github.com/getlantern/radiance"
)

var (
	baseDir        string
	logPort        int64
	server         vpn.VPNServer
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
	log.Debug("setupRadiance called")
	platform := empty.EmptyPlatform{}
	r, err := radiance.NewRadiance(platform)
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

	setupOnce.Do(func() {
		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)
	})
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	if server == nil {
		s, err := vpn.NewVPNServer(&vpn.Opts{
			BaseDir: baseDir,
			LogPort: logPort,
		})
		if err != nil {
			err = fmt.Errorf("unable to create VPN server: %v", err)
			log.Error(err)
			return C.CString(err.Error())
		}

		server = s
	}

	if err := start(context.Background()); err != nil {
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
	log.Debug("stopVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

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
	serverMu.Lock()
	defer serverMu.Unlock()

	if server == nil || !server.IsVPNConnected() {
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
