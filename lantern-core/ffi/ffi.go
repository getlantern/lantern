package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"encoding/json"
	"fmt"
	"sync"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/apps"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
)

type service string

const (
	appsService service = "apps"
	logsService service = "logs"
)

var (
	servicesMap = map[service]int64{}
	dataDir     string
	server      *radiance.Radiance
	serverMu    sync.Mutex
	serverOnce  sync.Once

	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

//export setup
func setup(dir *C.char, logPort, appsPort C.int64_t, api unsafe.Pointer) {
	dataDir = C.GoString(dir)

	serverOnce.Do(func() {

		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)

		servicesMap[logsService] = int64(logPort)
		servicesMap[appsService] = int64(appsPort)

		go apps.LoadInstalledApps(func(appData *apps.AppData) error {
			data, err := json.Marshal(appData)
			if err != nil {
				return err
			}
			dart_api_dl.SendToPort(int64(appsPort), string(data))
			return nil
		})

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
	log.Debug("startVPN called")

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
	log.Debug("stopVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

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
	serverMu.Lock()
	defer serverMu.Unlock()

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
