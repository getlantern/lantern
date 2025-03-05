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

	log = golog.LoggerFor("lantern.ffi")
)

// startVPN initializes and starts radiance if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	if server == nil {
		s, err := radiance.NewRadiance()
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

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

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
	vpnMutex.Lock()
	defer vpnMutex.Unlock()

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
