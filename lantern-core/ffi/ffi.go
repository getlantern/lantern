package main

/*
#include <stdlib.h>
#include "stdint.h"

*/
import "C"

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"sync/atomic"
	"unsafe"

	"github.com/getlantern/radiance/api"

	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/apps"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
	privateserver "github.com/getlantern/lantern-outline/lantern-core/private-server"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
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
	lanternCore       atomic.Pointer[lanterncore.Core]
	appsPort          int64
	logsPort          int64
	statusPort        int64
	privateserverPort int64
)

func core() lanterncore.Core {
	c := lanternCore.Load()
	return *c
}

func requireCore() (lanterncore.Core, *C.char) {
	c := lanternCore.Load()
	if c == nil {
		// consistent error payload so Dart can surface it
		return nil, C.CString(`{"error":"not_initialized"}`)
	}
	return *c, nil
}

func enableSplitTunneling() bool {
	return false
}

func sendApps(port int64) func(apps ...*apps.AppData) error {
	return func(apps ...*apps.AppData) error {
		data, err := json.Marshal(apps)
		if err != nil {
			slog.Error("Error marshalling apps:", "error", err)
			return err
		}
		go dart_api_dl.SendToPort(port, string(data))
		return nil
	}
}

//export setup
func setup(_logDir, _dataDir, _locale *C.char, logP, appsP, statusP, privateServerP C.int64_t, api unsafe.Pointer) *C.char {
	core, err := lanterncore.New(&utils.Opts{
		LogDir:   C.GoString(_logDir),
		DataDir:  C.GoString(_dataDir),
		Locale:   C.GoString(_locale),
		Deviceid: "",
		LogLevel: "debug",
	})
	if err != nil {
		return C.CString(fmt.Sprintf("unable to create LanternCore: %v", err))
	}
	lanternCore.Store(&core)
	logsPort = int64(logP)
	appsPort = int64(appsP)
	statusPort = int64(statusP)
	privateserverPort = int64(privateServerP)

	slog.Debug("Radiance setup successfully")
	return C.CString("ok")
}

//export addSplitTunnelItem
func addSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}

	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)

	if err := c.AddSplitTunnelItem(filterType, item); err != nil {
		return C.CString(fmt.Sprintf("error adding item: %v", err))
	}
	slog.Debug("added %s split tunneling item %s", filterType, item)
	return nil
}

//export removeSplitTunnelItem
func removeSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)

	if err := c.RemoveSplitTunnelItem(filterType, item); err != nil {
		return C.CString(fmt.Sprintf("error removing item: %v", err))
	}
	slog.Debug("removed %s split tunneling item %s", filterType, item)
	return nil
}

//export getDataCapInfo
func getDataCapInfo() *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	info, err := c.DataCapInfo()
	if err != nil {
		return SendError(err)
	}
	data, err := json.Marshal(info)
	if err != nil {
		return SendError(err)
	}
	return C.CString(string(data))
}

//export reportIssue
func reportIssue(emailC, typeC, descC, deviceC, modelC, logPathC *C.char) *C.char {
	email := C.GoString(emailC)
	issueType := C.GoString(typeC)
	desc := C.GoString(descC)
	device := C.GoString(deviceC)
	model := C.GoString(modelC)
	logPath := C.GoString(logPathC)

	if err := core().ReportIssue(email, issueType, desc, device, model, logPath); err != nil {
		return C.CString(fmt.Sprintf("error reporting issue: %v", err))
	}

	slog.Debug(
		"Reported issue: %s – %s on %s/%s",
		email, issueType, device, model,
	)
	return C.CString("ok")
}

// startVPN initializes and starts the VPN server if it is not already running.
//
//export startVPN
func startVPN(_logDir, _dataDir, _locale *C.char) *C.char {
	slog.Debug("startVPN called")
	sendStatusToPort(Connecting)
	if err := vpn_tunnel.StartVPN(nil, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	}); err != nil {
		err = fmt.Errorf("unable to start vpn server: %v", err)
		sendStatusToPort(Disconnected)
		return C.CString(err.Error())
	}
	sendStatusToPort(Connected)
	slog.Debug("VPN server started successfully")
	return C.CString("ok")
}

// stopVPN stops the VPN server if it is running.
//
//export stopVPN
func stopVPN() *C.char {
	slog.Debug("stopVPN called")
	sendStatusToPort(Disconnecting)
	if err := vpn_tunnel.StopVPN(); err != nil {
		err = fmt.Errorf("unable to stop vpn server: %v", err)
		sendStatusToPort(Connected)
		return C.CString(err.Error())
	}
	sendStatusToPort(Disconnected)
	slog.Debug("VPN server stopped successfully")
	return C.CString("ok")
}

// GetAvailableServers returns the available servers in JSON format.
//
//export getAvailableServers
func getAvailableServers() *C.char {
	return C.CString(string(core().GetAvailableServers()))
}

// connectToServer sets the private server with the given tag.
// connectToServer connects to a specific VPN server identified by the location type and tag.
// connectToServer will open and start the VPN tunnel if it is not already running.
//
//export connectToServer
func connectToServer(_location, _tag, _logDir, _dataDir, _locale *C.char) *C.char {
	tag := C.GoString(_tag)
	locationType := C.GoString(_location)

	// Valid location types are:
	// auto,
	// privateServer,
	// lanternLocation;
	if err := vpn_tunnel.ConnectToServer(locationType, tag, nil, &utils.Opts{
		DataDir: C.GoString(_dataDir),
		Locale:  C.GoString(_locale),
	}); err != nil {
		return SendError(fmt.Errorf("Error setting private server: %v", err))
	}
	slog.Debug("Private server set with tag", "tag", tag)
	return C.CString("ok")
}

func sendStatusToPort(status VPNStatus) {
	if statusPort == 0 {
		slog.Error("Status port is not set, cannot send status")
		return
	}
	go func() {
		msg := map[string]any{"status": status}
		data, _ := json.Marshal(msg)
		dart_api_dl.SendToPort(statusPort, string(data))
	}()
}

// isVPNConnected checks if the VPN server is running and connected.
//
//export isVPNConnected
func isVPNConnected() *C.char {
	connected := vpn_tunnel.IsVPNRunning()
	if connected {
		sendStatusToPort(Connected)
	} else {
		sendStatusToPort(Disconnected)
	}
	return C.CString("ok")
}

// APIS
func createUser() (*api.UserDataResponse, error) {
	slog.Debug("Creating user")
	return core().CreateUser()
}

// Get user data from the local config
//
//export getUserData
func getUserData() *C.char {
	c, errStr := requireCore()
	if errStr != nil {
		return errStr
	}
	slog.Debug("Getting user data locally")
	bytes, err := c.UserData()
	if err != nil {
		return SendError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// Get user data from the server
//
//export fetchUserData
func fetchUserData() *C.char {
	slog.Debug("Getting user data")
	bytes, err := core().FetchUserData()
	if err != nil {
		return SendError(fmt.Errorf("error marshalling user data: %v", err))
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
	planID := C.GoString(_planId)
	email := C.GoString(_email)
	slog.Debug("subscription type:", "subscriptionType", subscriptionType)
	redirect, err := core().StripeSubscriptionPaymentRedirect(subscriptionType, planID, email)
	if err != nil {
		return SendError(err)
	}
	slog.Debug("stripeSubscriptionPaymentRedirect response:", "redirect", redirect)
	return C.CString(redirect)
}

// Fetch payment redirect link for providers like alipay
//
//export paymentRedirect
func paymentRedirect(_plan, _provider, _email *C.char) *C.char {
	plan := C.GoString(_plan)
	provider := C.GoString(_provider)
	email := C.GoString(_email)

	redirect, err := core().PaymentRedirect(provider, plan, email)
	if err != nil {
		return SendError(err)
	}
	slog.Debug("PaymentRedirect response:", "redirect", redirect)
	return C.CString(redirect)
}

// Fetch stripe subscription link
//
//export stripeBillingPortalUrl
func stripeBillingPortalUrl() *C.char {
	url, err := core().StripeBillingPortalUrl()
	if err != nil {
		return SendError(err)
	}
	slog.Debug("StripeBillingPortalUrl response", "url", url)
	return C.CString(url)
}

// Fetch plans from the server
//
//export plans
func plans() *C.char {
	slog.Debug("Getting plans")
	jsonData, err := core().Plans("non-store")
	if err != nil {
		return SendError(err)
	}
	return C.CString(jsonData)
}

// OAuth methods
//
//export oauthLoginUrl
func oauthLoginUrl(_provider *C.char) *C.char {
	provider := C.GoString(_provider)
	url, err := core().OAuthLoginUrl(provider)
	if err != nil {
		return SendError(err)
	}
	slog.Debug("OAuthLoginURL response:", "url", url)
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
	slog.Debug("Getting OAuth login callback")
	oAuthToken := C.GoString(_oAuthToken)
	bytes, err := core().OAuthLoginCallback(oAuthToken)
	if err != nil {
		return SendError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// User management
//
// login is called when the user logs in with email and password.
//
//export login
func login(_email, _password *C.char) *C.char {
	email := C.GoString(_email)
	password := C.GoString(_password)
	bytes, err := core().Login(email, password)
	if err != nil {
		return SendError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// signup is called when the user signs up with email and password.
//
//export signup
func signup(_email, _password *C.char) *C.char {
	slog.Debug("Signing up user")
	email := C.GoString(_email)
	password := C.GoString(_password)
	err := core().SignUp(email, password)
	if err != nil {
		return SendError(err)
	}
	return C.CString("ok")
}

//export logout
func logout(_email *C.char) *C.char {
	email := C.GoString(_email)
	slog.Debug("Logging out")
	bytes, err := core().Logout(email)
	if err != nil {
		return SendError(fmt.Errorf("error logging out: %v", err))
	}
	encoded := base64.StdEncoding.EncodeToString(bytes)
	return C.CString(encoded)
}

// startRecoveryByEmail will send recovery code to the email
//
//export startRecoveryByEmail
func startRecoveryByEmail(_email *C.char) *C.char {
	email := C.GoString(_email)
	slog.Debug("Starting recovery by email for", "email", email)
	err := core().StartRecoveryByEmail(email)
	if err != nil {
		return SendError(fmt.Errorf("error starting recovery by email: %v", err))
	}
	slog.Debug("Recovery by email started successfully")
	return C.CString("ok")
}

// Validate email recovery code
//
//export validateEmailRecoveryCode
func validateEmailRecoveryCode(_email, _code *C.char) *C.char {
	email := C.GoString(_email)
	code := C.GoString(_code)
	slog.Debug("Validating email recovery with code", "email", email, "code", code)
	err := core().ValidateChangeEmailCode(email, code)
	if err != nil {
		return SendError(fmt.Errorf("invalid_code: %v", err))
	}
	slog.Debug("Email recovery code validated successfully")
	return C.CString("ok")
}

// Complete recovery by email
//
//export completeRecoveryByEmail
func completeRecoveryByEmail(_email, _newPassword, _code *C.char) *C.char {
	email := C.GoString(_email)
	code := C.GoString(_code)
	newPassword := C.GoString(_newPassword)
	slog.Debug("Completing recovery by email for %s with code %s", email, code)
	err := core().CompleteChangeEmail(email, newPassword, code)
	if err != nil {
		return SendError(fmt.Errorf("%v", err))
	}
	slog.Debug("Recovery by email completed successfully")
	return C.CString("ok")
}

// startChangeEmail initiates the process of changing the user's email address.
//
//export startChangeEmail
func startChangeEmail(_newEmail, _password *C.char) *C.char {
	newEmail := C.GoString(_newEmail)
	password := C.GoString(_password)
	err := core().StartChangeEmail(newEmail, password)
	if err != nil {
		return SendError(fmt.Errorf("error starting email change: %v", err))
	}
	return C.CString("ok")
}

// completeChangeEmail completes the process of changing the user's email address.
//
//export completeChangeEmail
func completeChangeEmail(_newEmail, _password, _code *C.char) *C.char {
	newEmail := C.GoString(_newEmail)
	password := C.GoString(_password)
	code := C.GoString(_code)
	err := core().CompleteChangeEmail(newEmail, password, code)
	if err != nil {
		return SendError(fmt.Errorf("error completing email change: %v", err))
	}
	return C.CString("ok")
}

// Delete account permanently
//
//export deleteAccount
func deleteAccount(_email, _password *C.char) *C.char {
	email := C.GoString(_email)
	password := C.GoString(_password)
	slog.Debug("Deleting account for:", "email", email)
	bytes, err := core().DeleteAccount(email, password)
	if err != nil {
		return SendError(fmt.Errorf("Error deleting account: %v", err))
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
	slog.Debug("Getting activation code")
	err := core().ActivationCode(email, resellerCode)
	if err != nil {
		return SendError(err)
	}
	slog.Debug("ActivationCode success")
	return C.CString("ok")
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

func main() {

}

// Private server methods

// interface that interact with the private server

type ffiPrivateServerEventListener struct{}

func (l *ffiPrivateServerEventListener) OnPrivateServerEvent(event string) {
	slog.Debug("Private server event:", "event", event)
	sendPrivateServerEvent(event)
}

func (l *ffiPrivateServerEventListener) OnError(err string) {
	slog.Debug("Private server error:", "err", err)
	sendPrivateServerEvent(err)
}

func (l *ffiPrivateServerEventListener) OpenBrowser(url string) error {
	slog.Debug("Opening browser with URL:", "url", url)
	mapStatus := map[string]string{
		"status": "openBrowser",
		"data":   url,
	}
	jsonData, _ := json.Marshal(mapStatus)
	sendPrivateServerEvent(string(jsonData))
	return nil
}

func sendPrivateServerEvent(event string) {
	if privateserverPort == 0 {
		slog.Error("Private server port is not set, cannot send event")
		return
	}

	go func() {
		dart_api_dl.SendToPort(privateserverPort, event)
	}()
}

// digitalOceanPrivateServer starts the DigitalOcean private server flow.
//
//export digitalOceanPrivateServer
func digitalOceanPrivateServer() *C.char {
	ffiEventListener := &ffiPrivateServerEventListener{}
	err := core().DigitalOceanPrivateServer(ffiEventListener)
	if err != nil {
		slog.Error("Error starting DigitalOcean private server flow:", "err", err)
		return SendError(err)
	}
	slog.Debug("DigitalOcean private server flow started successfully")
	return C.CString("ok")
}

// googleCloudPrivateServer starts the Google Cloud private server flow.
//
//export googleCloudPrivateServer
func googleCloudPrivateServer() *C.char {
	ffiEventListener := &ffiPrivateServerEventListener{}
	err := core().GoogleCloudPrivateServer(ffiEventListener)
	if err != nil {
		return SendError(fmt.Errorf("Error starting Google Cloud private server flow: %v", err))
	}
	slog.Debug("Google Cloud private server flow started successfully")
	return C.CString("ok")
}

// selectAccount selects the account for the private server.
//
//export selectAccount
func selectAccount(_account *C.char) *C.char {
	account := C.GoString(_account)
	slog.Debug("Selecting account:", "account", account)
	if err := core().SelectAccount(account); err != nil {
		return SendError(fmt.Errorf("Error selecting account: %v", err))
	}
	slog.Debug("Account selected successfully:", "account", account)
	return C.CString("ok")
}

// selectedProject selects the project for the private server.
//
//export selectProject
func selectProject(_project *C.char) *C.char {
	project := C.GoString(_project)
	err := core().SelectProject(project)
	if err != nil {
		return SendError(fmt.Errorf("Error getting selected project: %v", err))
	}
	slog.Debug("Selected project:", "project", project)
	return C.CString("ok")
}

// startDepolyment starts the deployment for the private server.
//
//export startDepolyment
func startDepolyment(_selectedLocation, _serverName *C.char) *C.char {
	location := C.GoString(_selectedLocation)
	serverName := C.GoString(_serverName)

	slog.Debug("Starting deployment with location: %s and plan: %s", location, serverName)
	err := core().StartDeployment(location, serverName)
	if err != nil {
		return SendError(fmt.Errorf("Error starting deployment: %v", err))
	}
	slog.Debug("Deployment started successfully with location: %s and plan: %s", location, serverName)
	return C.CString("ok")
}

// setCert sets the certificate fingerprint for the private server.
//
//export setCert
func setCert(fp *C.char) *C.char {
	slog.Debug("Setting cert")
	privateserver.SelectedCertFingerprint(C.GoString(fp))
	slog.Debug("Cert set successfully")
	return C.CString("ok")
}

// cancelDepolyment cancels the deployment for the private server.
//
//export cancelDepolyment
func cancelDepolyment() *C.char {
	slog.Debug("Cancelling deployment")
	if err := core().CancelDeployment(); err != nil {
		return SendError(fmt.Errorf("Error cancelling deployment: %v", err))
	}
	slog.Debug("Deployment cancelled successfully")
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

	err := core().AddServerManagerInstance(ip, port, accessToken, tag, ffiEventListener)
	if err != nil {
		return SendError(fmt.Errorf("Error adding server manager instance: %v", err))
	}
	slog.Debug("Server manager instance added successfully with IP: %s, Port: %s, AccessToken: %s, Tag: %s", ip, port, accessToken, tag)
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
	slog.Debug("Inviting to server manager instance:", "ip", ip, "port", port, "inviteName", inviteName)
	invite, err := core().InviteToServerManagerInstance(ip, port, accessToken, inviteName)
	if err != nil {
		return SendError(fmt.Errorf("Error inviting to server manager instance: %v", err))
	}
	slog.Debug("Invite created successfully:", "invite", invite)
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
	slog.Debug("Revoking invite:", "inviteName", inviteName, "ip", ip, "port", port)
	err := core().RevokeServerManagerInvite(ip, port, accessToken, inviteName)
	if err != nil {
		return SendError(fmt.Errorf("Error revoking server manager invite: %v", err))
	}
	slog.Debug("Invite revoked successfully:", "inviteName", inviteName, "ip", ip, "port", port)
	return C.CString("ok")
}
