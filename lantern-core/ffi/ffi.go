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

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
)

type VPNStatus string

const (
	Connecting    VPNStatus = "Connecting"
	Connected     VPNStatus = "Connected"
	Disconnecting VPNStatus = "Disconnecting"
	Disconnected  VPNStatus = "Disconnected"
	Error         VPNStatus = "Error"
)

var (
	server     *lanternService
	serverMu   sync.Mutex
	serverOnce sync.Once

	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

type lanternService struct {
	*radiance.Radiance

	servicePort int64
}

//export setup
func setup(_logDir, _dataDir *C.char, port C.int64_t, api unsafe.Pointer) {
	serverOnce.Do(func() {

		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)

		logDir := C.GoString(_logDir)
		dataDir := C.GoString(_dataDir)

		servicePort := int64(port)

		r, err := radiance.NewRadiance(client.Options{
			DataDir: dataDir,
			LogDir:  logDir,
		})
		if err != nil {
			log.Fatalf("unable to create VPN server: %v", err)
		}
		log.Debugf("created new instance of radiance with data directory %s", dataDir)

		server = &lanternService{
			Radiance:    r,
			servicePort: servicePort,
		}
	})
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	slog.Debug("startVPN called")

	serverMu.Lock()
	defer serverMu.Unlock()

	if server == nil {
		return C.CString("radiance not initialized")
	}

	server.sendStatusToPort(Connecting)

	if err := server.StartVPN(); err != nil {
		err = fmt.Errorf("unable to start vpn server: %v", err)
		server.sendStatusToPort(Disconnected)
		return C.CString(err.Error())
	}

	server.sendStatusToPort(Connected)
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

	if server == nil {
		return C.CString("radiance not initialized")
	}

	server.sendStatusToPort(Disconnecting)

	if err := server.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop vpn server: %v", err)
		server.sendStatusToPort(Connected)
		return C.CString(err.Error())
	}

	server.sendStatusToPort(Disconnected)
	log.Debug("VPN server stopped successfully")

	return nil
}

func (s *lanternService) sendStatusToPort(status VPNStatus) {
	go func() {
		msg := fmt.Sprintf(`{"status":"%s"}`, status)
		data, _ := json.Marshal(msg)
		dart_api_dl.SendToPort(s.servicePort, string(data))
	}()
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
