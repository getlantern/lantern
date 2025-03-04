package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"context"
	"fmt"
	"math/rand"
	"sync"
	"time"
	"unsafe"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/dart_api_dl"
	"github.com/getlantern/lantern-outline/vpn"
)

var (
	vpnMutex sync.Mutex
	server   vpn.VPNServer

	logPort int64 = 0
	logMu   sync.Mutex

	setupOnce sync.Once

	timerStarted bool

	log = golog.LoggerFor("lantern-outline.ffi")
)

//export setup
func setup(api unsafe.Pointer) {
	setupOnce.Do(func() {
		dart_api_dl.Init(api)
	})
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	log.Debug("startVPN called")

	vpnMutex.Lock()
	defer vpnMutex.Unlock()

	if server == nil {
		s, err := vpn.NewVPNServer(&vpn.Opts{Address: ":0"})
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

	if err := server.Stop(); err != nil {
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

	if server == nil || !server.IsVPNConnected() {
		return 0
	}

	return 1
}

//export setLogPort
func setLogPort(port C.int64_t) {
	logMu.Lock()
	defer logMu.Unlock()
	// Save the port (cast to Dart_Port).
	logPort = int64(port)
	// Start the log timer once.
	if !timerStarted {
		timerStarted = true
		go startLogTimer()
	}
}

//export InitializeDartApi
func InitializeDartApi(api unsafe.Pointer) {
	dart_api_dl.Init(api)
}

// TESTING
// startLogTimer creates a ticker that fires every five seconds.
func startLogTimer() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		<-ticker.C
		sendRandomLog()
	}
}

// sendRandomLog creates a random log message and calls the registered callback.
func sendRandomLog() {
	logMu.Lock()
	port := logPort
	logMu.Unlock()

	if port == 0 {
		return
	}

	// Create a random log message.
	logMsg := fmt.Sprintf("Random log message: %d", rand.Int())
	fmt.Println("Sending random log message %s", logMsg)
	cstr := C.CString(logMsg)
	defer C.free(unsafe.Pointer(cstr))

	// Post the log message to the Dart port.
	dart_api_dl.SendToPort(port, C.GoString(cstr))
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
