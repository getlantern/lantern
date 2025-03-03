package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"fmt"
	"sync"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
)

var (
	vpnMutex sync.Mutex
	server   *radiance.Radiance

	log = golog.LoggerFor("lantern-outline.ffi")
)

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		s, err := radiance.NewRadiance()
		if err != nil {
			err = fmt.Errorf("unable to create VPN server: %v", err)
			log.Error(err)
			return C.CString(err.Error())
		}
		server = s
	}
	if err := start(context.Background(), server); err != nil {
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

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	if server == nil {
		log.Debug("VPN server is not running")
		return nil
	}

	if err := server.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop VPN server: %v", err)
		log.Error(err)
		return C.CString(err.Error())
	}

	// Make sure to clear out the server after a successful stop
	server = nil

	log.Debug("VPN server stopped successfully")
	return nil
}

// isVPNConnected checks if the VPN server is running and connected.
//
//export isVPNConnected
func isVPNConnected() int {
	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	// if server == nil || !server.IsVPNConnected() {
	// 	return 0
	// }
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
