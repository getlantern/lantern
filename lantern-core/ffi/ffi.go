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
	"strconv"
	"sync"
	"unsafe"

	"log/slog"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/apps"
	privateserver "github.com/getlantern/lantern-outline/lantern-core/private-server"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"google.golang.org/protobuf/proto"

	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	"github.com/getlantern/lantern-outline/lantern-core/types"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/common"
)

type service string

const (
	appsService          service = "apps"
	logsService          service = "logs"
	statusService        service = "status"
	privateserverService service = "privateServer"
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
	apiClient          *api.APIClient
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
func setup(_logDir, _dataDir, _locale *C.char, logPort, appsPort, statusPort, privateServerPort C.int64_t, api unsafe.Pointer) *C.char {
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
			Radiance:  r,
			apiClient: r.APIHandler(),
			vpnClient: vpn,
			dataDir:   dataDir,
			servicesMap: map[service]int64{
				logsService:          int64(logPort),
				appsService:          int64(appsPort),
				statusService:        int64(statusPort),
				privateserverService: int64(privateServerPort),
			},
			splitTunnelHandler: vpn.SplitTunnelHandler(),
			userInfo:           r.UserInfo(),
		}

		if server.userInfo.LegacyID() == 0 {
			createUser()
		}
		fetchUserData()

	})
	if outError != nil {
		return C.CString(outError.Error())
	}
	log.Debugf("Radiance setup successfully")
	return C.CString("ok")

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

//export reportIssue
func reportIssue(emailC, typeC, descC *C.char) *C.char {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		return C.CString("radiance not initialized")
	}

	email := C.GoString(emailC)
	issueType := C.GoString(typeC)
	desc := C.GoString(descC)

	report := &radiance.IssueReport{
		Type:        issueType,
		Description: desc,
	}
	err := server.ReportIssue(email, report)
	if err != nil {
		return C.CString(fmt.Sprintf("error: %v", err))
	}
	return C.CString("ok")
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

	return C.CString("ok")
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
	return C.CString("ok")
}

// setPrivateServer sets the private server with the given tag.
//
//export setPrivateServer
func setPrivateServer(_location, _tag *C.char) *C.char {
	tag := C.GoString(_tag)
	locationType := types.LocationType(C.GoString(_location))

	// Valid location types are:
	// auto,
	// privateServer,
	// lanternLocation;
	group, tagName, err := types.LocationGroupAndTag(locationType, tag)
	if err != nil {
		return SendError(log.Errorf("Invalid locationType: %s", locationType))
	}

	if err := server.vpnClient.SelectServer(group, tagName); err != nil {
		return SendError(log.Errorf("Error setting private server: %v", err))
	}
	log.Debugf("Private server set with tag: %s", tagName)
	return C.CString("ok")
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

// APIS
func createUser() (*api.UserDataResponse, error) {
	log.Debug("Creating user")
	user, err := server.apiClient.NewUser(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}

	return user, nil
}

// Get user data from the local config
//
//export getUserData
func getUserData() *C.char {
	log.Debug("Getting user data locally")
	user, err := server.userInfo.GetData()
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
//
//export fetchUserData
func fetchUserData() *C.char {
	log.Debug("Getting user data")
	user, err := server.apiClient.UserData(context.Background())
	if err != nil {
		return SendError(fmt.Errorf("error getting user data: %v", err))
	}
	//Convert user to UserResponse
	userResponse := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	log.Debugf("UserData response: %v", userResponse)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
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
	redirectBody := api.PaymentRedirectData{
		Provider:    "stripe",
		Plan:        planId,
		DeviceName:  server.userInfo.DeviceID(),
		Email:       email,
		BillingType: api.SubscriptionType(subscriptionType),
	}
	redirect, err := subscriptionPaymentRedirect(redirectBody)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("stripeSubscriptionPaymentRedirect response: %s", redirect)
	return C.CString(*redirect)
}

// Fetch payment redirect link for providers like alipay
//
//export paymentRedirect
func paymentRedirect(_plan, _provider, _email *C.char) *C.char {
	plan := C.GoString(_plan)
	provider := C.GoString(_provider)
	email := C.GoString(_email)
	deviceName := server.userInfo.DeviceID()

	body := api.PaymentRedirectData{
		Plan:       plan,
		Provider:   provider,
		Email:      email,
		DeviceName: deviceName,
	}
	redirect, err := server.apiClient.PaymentRedirect(context.Background(), body)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("PaymentRedirect response: %s", redirect)
	return C.CString(redirect)
}

// Fetch stripe subscription link
//
//export stripeBillingPortalUrl
func stripeBillingPortalUrl() *C.char {
	url, err := server.apiClient.StripeBillingPortalUrl()
	if err != nil {
		return SendError(err)
	}
	log.Debugf("StripeBilingPortalUrl response: %s", url)
	return C.CString(url)
}

// Fetch plans from the server
//
//export plans
func plans() *C.char {
	log.Debug("Getting plans")
	plans, err := server.apiClient.SubscriptionPlans(context.Background(), "non-store")
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

func subscriptionPaymentRedirect(redirectBody api.PaymentRedirectData) (*string, error) {
	rediret, err := server.apiClient.SubscriptionPaymentRedirectURL(context.Background(), redirectBody)
	if err != nil {
		return nil, log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return &rediret, nil
}

// OAuth methods
//
//export oauthLoginUrl
func oauthLoginUrl(_provider *C.char) *C.char {
	provider := C.GoString(_provider)
	url, err := server.apiClient.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("OAuthLoginURL response: %s", url)
	return C.CString(url)
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
	server.userInfo.SetData(login)
	///Get user data from api this will also save data in user config
	user, err := server.apiClient.UserData(context.Background())

	if err != nil {
		return SendError(log.Errorf("Error getting user data: %v", err))
	}
	//Convert user to UserResponse
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

// User management
//
// login is called when the user logs in with email and password.
//
//export login
func login(_email *C.char, _password *C.char) *C.char {
	email := C.GoString(_email)
	password := C.GoString(_password)
	deviceId := server.userInfo.DeviceID()
	log.Debugf("Logging in user with email: %s %s", email, password)
	loginResponse, err := server.apiClient.Login(context.Background(), email, password, deviceId)
	if err != nil {
		log.Errorf("Error logging in: %v", err)
		return SendError(err)
	}
	log.Debugf("Login response: %v", loginResponse)
	// Set user data
	server.userInfo.SetData(loginResponse)

	bytes, err := proto.Marshal(loginResponse)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// signup is called when the user signs up with email and password.
//
//export signup
func signup(_email *C.char, _password *C.char) *C.char {
	log.Debug("Signing up user")
	email := C.GoString(_email)
	password := C.GoString(_password)
	err := server.apiClient.SignUp(context.Background(), email, password)
	if err != nil {
		return SendError(err)
	}
	return C.CString("ok")
}

//export logout
func logout(_email *C.char) *C.char {
	email := C.GoString(_email)
	log.Debug("Logging out")
	err := server.apiClient.Logout(context.Background(), email)
	if err != nil {
		return SendError(log.Errorf("Error logging out: %v", err))
	}
	log.Debug("Logged out successfully")
	// Clear user data
	user, err := createUser()
	if err != nil {
		return SendError(log.Errorf("Error creating user: %v", err))
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	server.userInfo.SetData(login)
	bytes, err := proto.Marshal(login)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// startRecoveryByEmail will send recovery code to the email
//
//export startRecoveryByEmail
func startRecoveryByEmail(_email *C.char) *C.char {
	email := C.GoString(_email)
	log.Debugf("Starting recovery by email for %s", email)
	err := server.apiClient.StartRecoveryByEmail(context.Background(), email)
	if err != nil {
		return SendError(log.Errorf("Error starting recovery by email: %v", err))
	}
	log.Debug("Recovery by email started successfully")
	return C.CString("ok")
}

// Validate email recovery code
//
//export validateEmailRecoveryCode
func validateEmailRecoveryCode(_email, _code *C.char) *C.char {
	email := C.GoString(_email)
	code := C.GoString(_code)
	log.Debugf("Validating email recovery code for %s with code %s", email, code)
	err := server.apiClient.ValidateEmailRecoveryCode(context.Background(), email, code)
	if err != nil {
		return SendError(log.Errorf("invalid_code: %v", err))
	}
	log.Debug("Email recovery code validated successfully")
	return C.CString("ok")
}

// Complete recovery by email
//
//export completeRecoveryByEmail
func completeRecoveryByEmail(_email, _newPassword, _code *C.char) *C.char {
	email := C.GoString(_email)
	code := C.GoString(_code)
	newPassword := C.GoString(_newPassword)
	log.Debugf("Completing recovery by email for %s with code %s", email, code)
	err := server.apiClient.CompleteRecoveryByEmail(context.Background(), email, newPassword, code)
	if err != nil {
		return SendError(log.Errorf("%v", err))
	}
	log.Debug("Recovery by email completed successfully")
	return C.CString("ok")
}

// Delete account permanently
//
//export deleteAccount
func deleteAccount(_email, _password *C.char) *C.char {
	email := C.GoString(_email)
	password := C.GoString(_password)
	log.Debugf("Deleting account for %s", email)
	err := server.apiClient.DeleteAccount(context.Background(), email, password)
	if err != nil {
		return SendError(log.Errorf("Error deleting account: %v", err))
	}
	log.Debug("Account deleted successfully")
	// Clear user data
	user, err := createUser()
	if err != nil {
		return SendError(log.Errorf("Error creating user: %v", err))
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	server.userInfo.SetData(login)
	bytes, err := proto.Marshal(login)
	if err != nil {
		return SendError(log.Errorf("Error marshalling user data: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// activationCode create subscription using activation code
//
//export activationCode
func activationCode(_email, _resellerCode *C.char) *C.char {
	email := C.GoString(_email)
	resellerCode := C.GoString(_resellerCode)
	log.Debug("Getting activation code")
	purchase, err := server.apiClient.ActivationCode(context.Background(), email, resellerCode)
	if err != nil {
		return SendError(err)
	}
	log.Debugf("ActivationCode response: %v", purchase)
	return C.CString("ok")
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

func main() {

}

//Private server methods

// interface that interact with the private server

type ffiPrivateServerEventListener struct{}

func (l *ffiPrivateServerEventListener) OnPrivateServerEvent(event string) {
	log.Debugf("Private server event: %s", event)
	sendPrivateServerEvent(event)
}

func (l *ffiPrivateServerEventListener) OnError(err string) {
	log.Debugf("Private server error: %v", err)
	sendPrivateServerEvent(err)
}

func (l *ffiPrivateServerEventListener) OpenBrowser(url string) error {
	log.Debugf("Opening browser with URL: %s", url)
	mapStatus := map[string]string{
		"status": "openBrowser",
		"data":   url,
	}
	jsonData, _ := json.Marshal(mapStatus)
	sendPrivateServerEvent(string(jsonData))
	return nil
}

func sendPrivateServerEvent(event string) {
	mu.Lock()
	defer mu.Unlock()

	if server == nil {
		log.Errorf("Radiance not initialized")
		return
	}

	servicePort, ok := server.servicesMap[privateserverService]
	if !ok {
		log.Errorf("Private server service not initialized")
		return
	}

	go func() {
		dart_api_dl.SendToPort(servicePort, event)
	}()
}

// digitalOceanPrivateServer starts the DigitalOcean private server flow.
//
//export digitalOceanPrivateServer
func digitalOceanPrivateServer() *C.char {
	ffiEventListener := &ffiPrivateServerEventListener{}
	err := privateserver.StartDigitalOceanPrivateServerFlow(ffiEventListener, server.vpnClient)
	if err != nil {
		log.Errorf("Error starting DigitalOcean private server flow: %v", err)
		return SendError(err)
	}
	log.Debug("DigitalOcean private server flow started successfully")
	return C.CString("ok")
}

// selectAccount selects the account for the private server.
//
//export selectAccount
func selectAccount(_account *C.char) *C.char {
	account := C.GoString(_account)
	log.Debugf("Selecting account: %s", account)
	if err := privateserver.SelectAccount(account); err != nil {
		return SendError(log.Errorf("Error selecting account: %v", err))
	}
	log.Debugf("Account %s selected successfully", account)
	return C.CString("ok")
}

// selectedProject selects the project for the private server.
//
//export selectProject
func selectProject(_project *C.char) *C.char {
	project := C.GoString(_project)
	err := privateserver.SelectProject(project)
	if err != nil {
		return SendError(log.Errorf("Error getting selected project: %v", err))
	}
	log.Debugf("Selected project: %s", project)
	return C.CString("ok")
}

// startDepolyment starts the deployment for the private server.
//
//export startDepolyment
func startDepolyment(_selectedLocation, _serverName *C.char) *C.char {
	location := C.GoString(_selectedLocation)
	serverName := C.GoString(_serverName)

	log.Debugf("Starting deployment with location: %s and plan: %s", location, serverName)
	err := privateserver.StartDepolyment(location, serverName)
	if err != nil {
		return SendError(log.Errorf("Error starting deployment: %v", err))
	}
	log.Debugf("Deployment started successfully with location: %s and plan: %s", location, serverName)
	return C.CString("ok")
}

// setCert sets the certificate fingerprint for the private server.
//
//export setCert
func setCert(fp *C.char) *C.char {
	log.Debug("Setting cert")
	privateserver.SelectedCertFingerprint(C.GoString(fp))
	log.Debugf("Cert set successfully")
	return C.CString("ok")
}

// cancelDepolyment cancels the deployment for the private server.
//
//export cancelDepolyment
func cancelDepolyment() *C.char {
	log.Debug("Cancelling deployment")
	if err := privateserver.CancelDepolyment(); err != nil {
		return SendError(log.Errorf("Error cancelling deployment: %v", err))
	}
	log.Debugf("Deployment cancelled successfully")
	return C.CString("ok")
}

// addServerManagerInstance adds a server manager instance manually.
//
//export addServerManagerInstance
func addServerManagerInstance(_ip, _port, _accessToken, _tag *C.char) *C.char {
	ffiEventListener := &ffiPrivateServerEventListener{}
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	tag := C.GoString(_tag)

	err := privateserver.AddServerManually(ip, port, accessToken, tag, server.vpnClient, ffiEventListener)
	if err != nil {
		return SendError(log.Errorf("Error adding server manager instance: %v", err))
	}
	log.Debugf("Server manager instance added successfully with IP: %s, Port: %s, AccessToken: %s, Tag: %s", ip, port, accessToken, tag)
	return C.CString("ok")
}

// inviteToServerManagerInstance invites to the server manager instance.
//
//export inviteToServerManagerInstance
func inviteToServerManagerInstance(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	inviteName := C.GoString(_inviteName)
	portInt, _ := strconv.Atoi(port)
	log.Debugf("Inviting to server manager instance %s:%s with invite name %s", ip, port, inviteName)
	invite, err := privateserver.InviteToServerManagerInstance(ip, portInt, accessToken, inviteName, server.vpnClient)
	if err != nil {
		return SendError(log.Errorf("Error inviting to server manager instance: %v", err))
	}
	log.Debugf("Invite created successfully: %s", invite)
	return C.CString(invite)
}

// revokeServerManagerInvite revokes the server manager invite.
//
//export revokeServerManagerInvite
func revokeServerManagerInvite(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	inviteName := C.GoString(_inviteName)
	portInt, _ := strconv.Atoi(port)
	log.Debugf("Revoking invite %s for server %s:%s", inviteName, ip, port)
	err := privateserver.RevokeServerManagerInvite(ip, portInt, accessToken, inviteName, server.vpnClient)
	if err != nil {
		return SendError(log.Errorf("Error revoking server manager invite: %v", err))
	}
	log.Debugf("Invite %s revoked successfully for server %s:%s", inviteName, ip, port)
	return C.CString("ok")
}
