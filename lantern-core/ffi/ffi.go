package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"runtime"
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/apps"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"google.golang.org/protobuf/proto"

	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/common"
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
	vpnClient          client.VPNClient
	servicesMap        map[service]int64
	dataDir            string
	splitTunnelHandler *client.SplitTunnel
	userInfo           common.UserInfo

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
func setup(_logDir, _dataDir, _locale *C.char, logPort, appsPort, statusPort C.int64_t, api unsafe.Pointer) *C.char {
	var outError error
	setupOnce.Do(func() {
		// initialize the Dart API DL bridge.
		dart_api_dl.Init(api)
		logDir := C.GoString(_logDir)
		dataDir := C.GoString(_dataDir)
		locale := C.GoString(_locale)

		opts := radiance.Options{
			DataDir: dataDir,
			LogDir:  logDir,
			Locale:  locale,
		}
		r, err := radiance.NewRadiance(opts)
		if err != nil {
			outError = log.Errorf("unable to create VPN server: %v", err)
		}
		log.Debugf("created new instance of radiance with data directory %s and logs dir %s", dataDir, logDir)

		// init app cache in background
		go apps.LoadInstalledApps(dataDir, sendApps(int64(appsPort)))

		vpn, err := client.NewVPNClient(opts.DataDir, opts.LogDir, nil, enableSplitTunneling())
		if err != nil {
			outError = log.Errorf("unable to create API handler: %v", err)
		}
		server = &lanternService{
			Radiance:   r,
			proServer:  r.APIHandler().ProServer,
			authClient: r.APIHandler().User,
			vpnClient:  vpn,
			dataDir:    dataDir,
			servicesMap: map[service]int64{
				logsService:   int64(logPort),
				appsService:   int64(appsPort),
				statusService: int64(statusPort),
			},
			splitTunnelHandler: vpn.SplitTunnelHandler(),
			userInfo:           r.UserInfo(),
		}

		if server.userInfo.LegacyID() == 0 {
			createUser()
		}

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

	if err := server.vpnClient.StartVPN(); err != nil {
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

	if err := server.vpnClient.StopVPN(); err != nil {
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
func isVPNConnected() *C.char {
	mu.Lock()
	defer mu.Unlock()
	if server == nil {
		return SendError(fmt.Errorf("radiance not initialized"))
	}
	connected := server.vpnClient.ConnectionStatus()
	if connected {
		server.sendStatusToPort(Connected)
	} else {
		server.sendStatusToPort(Disconnected)
	}
	return C.CString("ok")
}

//APIS

func createUser() error {
	log.Debug("Creating user")
	user, err := server.proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

// Get user data from the local config
//
//export getUserData
func getUserData() *C.char {
	log.Debug("Getting user data locally")
	user, err := server.UserInfo().GetUserData()
	if err != nil {
		return SendError(err)
	}
	bytes, err := proto.Marshal(user)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// Get user data from the server
func fetchUserData() (*protos.UserDataResponse, error) {
	log.Debug("Getting user data")
	user, err := server.proServer.UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	return user, nil
}

// Fetch stipe subscription payment redirect link
//
//export stripeSubscriptionPaymentRedirect
func stripeSubscriptionPaymentRedirect(subType, _planId, _email *C.char) *C.char {
	slog.Debug("stripeSubscriptionPaymentRedirect called")
	subscriptionType := C.GoString(subType)
	planId := C.GoString(_planId)
	email := C.GoString(_email)
	log.Debugf("subscription type: %s", subscriptionType)
	redirectBody := &protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             planId,
		DeviceName:       server.userInfo.DeviceID(),
		Email:            email,
		SubscriptionType: protos.SubscriptionType(subscriptionType),
	}

	redirect, err := subscriptionPaymentRedirect(redirectBody)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("stripeSubscriptionPaymentRedirect response: %s", *redirect)
	return C.CString(*redirect)
}

// Fetch stripe subscription link
//
//export stripeBilingPortalUrl
func stripeBilingPortalUrl() *C.char {
	url, err := server.proServer.StripeBilingPortalUrl()
	if err != nil {
		return SendError(err)
	}
	log.Debugf("StripeBilingPortalUrl response: %s", url.Redirect)
	return C.CString(url.Redirect)
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

// OAuth methods
//
//export oauthLoginUrl
func oauthLoginUrl(_provider *C.char) *C.char {
	provider := C.GoString(_provider)
	url, err := server.authClient.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("OAuthLoginURL response: %s", url.Redirect)
	return C.CString(url.Redirect)
}

// oauthLoginCallback is called when the user has logged in with OAuth and the callback URL is called.
//
//export oAuthLoginCallback
func oAuthLoginCallback(_oAuthToken *C.char) *C.char {
	// defer func() {
	// 	if err := recover(); err != nil {
	// 		log.Errorf("Error login callback : %v", err)
	// 	}
	// }()
	log.Debug("Getting OAuth login callback")
	oAuthToken := C.GoString(_oAuthToken)
	userInfo, err := utils.DecodeJWT(oAuthToken)
	if err != nil {
		return SendError(log.Errorf("Error decoding JWT: %v", err))
	}
	log.Debugf("UserInfo: %+v", userInfo)
	// Temporary  set user data to so api can read it
	login := &protos.LoginResponse{
		LegacyID:    userInfo.LegacyUserId,
		LegacyToken: userInfo.LegacyToken,
		LegacyUserData: &protos.LoginResponse_UserData{
			UserId: userInfo.LegacyUserId,
			Token:  userInfo.LegacyToken,
		},
	}
	server.userInfo.Save(login)
	///Get user data from api this will also save data in user config
	user, err := fetchUserData()
	if err != nil {
		return SendError(log.Errorf("Error getting user data: %v", err))
	}
	//Convert user to LoginResponse
	userResponse := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	log.Debugf("UserData response: %v", user)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

//export enforce_binding
func enforce_binding() {}

func main() {}
