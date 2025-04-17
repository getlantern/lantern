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
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/pro"
	"github.com/getlantern/radiance/user"
	"github.com/getlantern/radiance/user/protos"
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
	proServer   *pro.Pro
	authClient  *user.User
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
			proServer:   r.Pro(),
			authClient:  r.User(),
			servicePort: servicePort,
		}
		createUser()
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

	redirect, err := subscripationPaymentRedirect(redirectBody)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("stripeSubscriptionPaymentRedirect response: %s", *redirect)
	return C.CString(*redirect)
}

func subscripationPaymentRedirect(redirectBody *protos.SubscriptionPaymentRedirectRequest) (*string, error) {
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
