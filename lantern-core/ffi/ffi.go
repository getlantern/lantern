package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"encoding/json"
	"errors"
	"fmt"
	"runtime"
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/apps"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/sing-box-extensions/ruleset"
)

type service string

const (
	appsService service = "apps"
	logsService service = "logs"
)

var (
	server *lanternService
	mu     sync.Mutex

	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

type lanternService struct {
	*radiance.Radiance
	servicesMap        map[service]int64
	dataDir            string
	splitTunnelHandler *client.SplitTunnel

	mu sync.Mutex
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "darwin"
}

func sendApps(port int64) func(apps ...*apps.AppData) error {
	return func(apps ...*apps.AppData) error {
		data, err := json.Marshal(apps)
		if err != nil {
			log.Error(err)
			return err
		}
		dart_api_dl.SendToPort(port, string(data))
		return nil
	}
}

//export setupRadiance
func setupRadiance(dir *C.char, logPort, appsPort C.int64_t, api unsafe.Pointer) {
	log.Debug("Setup radiance called")
	setupOnce.Do(func() {
		dataDir := C.GoString(dir)

		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)

		r, err := radiance.NewRadiance(client.Options{
			DataDir:              dataDir,
			EnableSplitTunneling: enableSplitTunneling(),
		})
		if err != nil {
			log.Fatalf("unable to create VPN server: %v", err)
		}
		log.Debugf("created new instance of radiance with data directory %s", dataDir)

		// init app cache in background
		go apps.InitAppCache(sendApps(int64(appsPort)))

		server = &lanternService{
			Radiance: r,
			dataDir:  dataDir,
			servicesMap: map[service]int64{
				logsService: int64(logPort),
				appsService: int64(appsPort),
			},
			splitTunnelHandler: r.SplitTunnelHandler(),
		}
	})
}

func getService() (*lanternService, error) {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		return nil, errors.New("radiance not initialized")
	}
	return server, nil
}

//export addSplitTunnelPackage
func addSplitTunnelPackage(pkg *C.char) *C.char {
	rs, err := getService()
	if err != nil {
		return C.CString(err.Error())
	}

	if err = rs.splitTunnelHandler.AddItem(ruleset.TypePackageName, C.GoString(pkg)); err != nil {
		return C.CString(fmt.Sprintf("error adding package: %v", err))
	}
	return nil
}

//export removeSplitTunnelPackage
func removeSplitTunnelPackage(pkg *C.char) *C.char {
	rs, err := getService()
	if err != nil {
		return C.CString(err.Error())
	}

	if err = rs.SplitTunnelHandler().RemoveItem(ruleset.TypePackageName, C.GoString(pkg)); err != nil {
		return C.CString(fmt.Sprintf("error removing package: %v", err))
	}
	return nil
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	slog.Debug("startVPN called")

	rs, err := getService()
	if err != nil {
		return C.CString(err.Error())
	}

	if err := rs.StartVPN(); err != nil {
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

	rs, err := getService()
	if err != nil {
		return C.CString(err.Error())
	}

	if err := rs.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop vpn server: %v", err)
		return C.CString(err.Error())
	}

	slog.Debug("VPN server stopped successfully")
	return nil
}

// isVPNConnected checks if the VPN server is running and connected.
//
//export isVPNConnected
func isVPNConnected() int {
	rs, err := getService()
	if err != nil {
		log.Error(err)
		return 0
	}

	connected := rs.Radiance.ConnectionStatus()
	if connected {
		return 1
	}
	return 0
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
