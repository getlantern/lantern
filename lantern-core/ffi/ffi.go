package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"fmt"
	"sync"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
)

var (
	mu         sync.Mutex
	server     *radiance.Radiance
	serverOnce sync.Once

	log = golog.LoggerFor("lantern.ffi")
)

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	mu.Lock()
	defer mu.Unlock()

	var err error
	serverOnce.Do(func() {
		if server == nil {
			s, e := radiance.NewRadiance()
			if e != nil {
				err = fmt.Errorf("unable to create radiance: %v", e)
				return
			}
			server = s
		}
	})
	if err != nil {
		return C.CString(err.Error())
	}

	if err := server.StartVPN(); err != nil {
		err = fmt.Errorf("unable to create radiance: %v", err)
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

	if err := server.StopVPN(); err != nil {
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
