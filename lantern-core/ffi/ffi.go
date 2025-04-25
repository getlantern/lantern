package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"context"
	"encoding/json"
	"fmt"
	"runtime"
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/apps"

	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
)

type service string

const (
	appsService   service = "apps"
	logsService   service = "logs"
	statusService service = "status"
)

type VPNStatus string

const (
	enableLogging = false

	Connecting    VPNStatus = "Connecting"
	Connected     VPNStatus = "Connected"
	Disconnecting VPNStatus = "Disconnecting"
	Disconnected  VPNStatus = "Disconnected"
	Error         VPNStatus = "Error"
)

var (
	server    *lanternService
	mu        sync.Mutex
	setupOnce sync.Once

	log = golog.LoggerFor("lantern-outline.ffi")
)

type lanternService struct {
	*radiance.Radiance
	proServer          *api.Pro
	authClient         *api.User
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
		go dart_api_dl.SendToPort(port, string(data))
		return nil
	}
}

//export setup
func setup(_logDir, _dataDir *C.char, logPort, appsPort, statusPort C.int64_t, api unsafe.Pointer) *C.char {
	var outError error
	setupOnce.Do(func() {
		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)

		logDir := C.GoString(_logDir)
		dataDir := C.GoString(_dataDir)

		opts := client.Options{
			DataDir:              dataDir,
			LogDir:               logDir,
			EnableSplitTunneling: enableSplitTunneling(),
		}
		r, err := radiance.NewRadiance(opts)
		if err != nil {
			outError = log.Errorf("unable to create VPN server: %v", err)
		}
		log.Debugf("created new instance of radiance with data directory %s and logs dir %s", dataDir, logDir)

		// init app cache in background
		go apps.LoadInstalledApps(dataDir, sendApps(int64(appsPort)))

		apiHandler, err := radiance.NewAPIHandler(opts)
		if err != nil {
			outError = log.Errorf("unable to create API handler: %v", err)
		}
		server = &lanternService{
			Radiance:   r,
			proServer:  apiHandler.ProServer,
			authClient: apiHandler.User,
			dataDir:    dataDir,
			servicesMap: map[service]int64{
				logsService:   int64(logPort),
				appsService:   int64(appsPort),
				statusService: int64(statusPort),
			},
			splitTunnelHandler: r.SplitTunnelHandler(),
		}
		createUser()
	})
	if outError != nil {
		return C.CString(outError.Error())
	}
	log.Debugf("Radiance setup successfully")
	return nil

}

//export addSplitTunnelItem
func addSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		return C.CString("radiance not initialized")
	}

	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)

	if err := server.splitTunnelHandler.AddItem(filterType, item); err != nil {
		return C.CString(fmt.Sprintf("error adding item: %v", err))
	}
	log.Debugf("added %s split tunneling item %s", filterType, item)
	return nil
}

//export removeSplitTunnelItem
func removeSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		return C.CString("radiance not initialized")
	}

	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)

	if err := server.splitTunnelHandler.RemoveItem(filterType, item); err != nil {
		return C.CString(fmt.Sprintf("error removing item: %v", err))
	}
	log.Debugf("removed %s split tunneling item %s", filterType, item)
	return nil
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN() *C.char {
	slog.Debug("startVPN called")

	mu.Lock()
	defer mu.Unlock()

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

	mu.Lock()
	defer mu.Unlock()

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
	s.mu.Lock()
	defer s.mu.Unlock()
	servicePort, ok := s.servicesMap[statusService]
	if !ok {
		log.Errorf("status service not initialized")
		return
	}

	go func() {
		msg := map[string]any{"status": status}
		data, _ := json.Marshal(msg)
		dart_api_dl.SendToPort(servicePort, string(data))
	}()
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

	connected := server.ConnectionStatus()
	if connected {
		return 1
	}
	return 0
}

//APIS

func createUser() error {
	// defer func() {
	// 	if err := recover(); err != nil {
	// 		log.Errorf("Error creating user: %v", err)
	// 	}
	// }()
	log.Debug("Creating user")
	user, err := server.proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

// Fetch stipe subscription payment redirect link
//
//export stripeSubscriptionPaymentRedirect
func stripeSubscriptionPaymentRedirect(subType *C.char) *C.char {
	slog.Debug("stripeSubscriptionPaymentRedirect called")
	subscriptionType := C.GoString(subType)

	log.Debugf("subscription type: %s", subscriptionType)

	redirectBody := &protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             "1y-usd",
		DeviceName:       "test",
		Email:            "test@getlantern.org",
		SubscriptionType: protos.SubscriptionType(subscriptionType),
	}

	redirect, err := subscriptionPaymentRedirect(redirectBody)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("stripeSubscriptionPaymentRedirect response: %s", *redirect)
	return C.CString(*redirect)
}

// Fetch plans from the server
//
//export plans
func plans() *C.char {
	log.Debug("Getting plans")
	plans, err := server.proServer.Plans(context.Background())
	if err != nil {
		return SendError(err)
	}
	log.Debugf("Plans response: %v", plans)
	jsonData, innerErr := json.Marshal(plans)
	if innerErr != nil {
		return SendError(innerErr)
	}
	return C.CString(string(jsonData))
}

func subscriptionPaymentRedirect(redirectBody *protos.SubscriptionPaymentRedirectRequest) (*string, error) {
	rediret, err := server.proServer.SubscriptionPaymentRedirect(context.Background(), redirectBody)
	if err != nil {
		return nil, log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return &rediret.Redirect, nil
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
