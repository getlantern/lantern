//go:build !android && !ios && !macos

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

	"github.com/getlantern/radiance/common"

	lanterncore "github.com/getlantern/lantern/lantern-core"
	"github.com/getlantern/lantern/lantern-core/apps"
	"github.com/getlantern/lantern/lantern-core/dart_api_dl"
	"github.com/getlantern/lantern/lantern-core/utils"
	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

// runOnGoStack wraps common.RunOffCgoStack for FFI functions that return *C.char.
// CGo-exported functions run on a callback stack whose memory isn't tracked
// by the GC heap bitmap. Allocating Go pointers (like C.CString or base64
// encoding) on that stack triggers bulkBarrierPreWrite panics.
func runOnGoStack(fn func() *C.char) *C.char {
	result, _ := common.RunOffCgoStack(func() (*C.char, error) {
		return fn(), nil
	})
	return result
}

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
	appEventPort      int64
)

func requireCore() (lanterncore.Core, *C.char) {
	c := lanternCore.Load()
	if c == nil {
		return nil, C.CString(`{"error":"not_initialized"}`)
	}
	return *c, nil
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

// / Flutter event emitter implementation for FFI
type ffiFlutterEventEmitter struct{}

func (e *ffiFlutterEventEmitter) SendEvent(event *utils.FlutterEvent) {
	slog.Debug("Sending event to Flutter:", "event", event)
	if appEventPort == 0 {
		slog.Error("Apps port is not set, cannot send event")
		return
	}
	eventData, err := json.Marshal(event)
	if err != nil {
		slog.Error("Error marshalling event:", "error", err)
		return
	}
	slog.Debug("Marshalled event data:", "data", string(eventData))
	go dart_api_dl.SendToPort(appEventPort, string(eventData))
}

//export setup
func setup(_logDir, _dataDir, _locale, _env *C.char, logP, appsP, statusP, privateServerP, appEventP C.int64_t, consent C.int, api unsafe.Pointer) *C.char {
	return runOnGoStack(func() *C.char {
		core, err := lanterncore.New(&utils.Opts{
			LogDir:           C.GoString(_logDir),
			DataDir:          C.GoString(_dataDir),
			Locale:           C.GoString(_locale),
			Env:              C.GoString(_env),
			Deviceid:         "",
			LogLevel:         lanterncore.DefaultLogLevel,
			TelemetryConsent: consent == 1,
		}, &ffiFlutterEventEmitter{})

		if err != nil {
			return C.CString(fmt.Sprintf("unable to create LanternCore: %v", err))
		}
		dart_api_dl.Init(api)
		lanternCore.Store(&core)
		logsPort = int64(logP)
		appsPort = int64(appsP)
		statusPort = int64(statusP)
		privateserverPort = int64(privateServerP)
		appEventPort = int64(appEventP)

		slog.Debug("Radiance setup successfully")
		return C.CString("ok")
	})
}

// updateTelemetryConsent updates the telemetry consent.
//
//export updateTelemetryConsent
func updateTelemetryConsent(consent C.int) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		err := c.UpdateTelemetryConsent(consent != 0)
		if err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// availableFeatures returns a list of available features in JSON format.
//
//export availableFeatures
func availableFeatures() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		return C.CString(string(c.AvailableFeatures()))
	})
}

//export updateLocale
func updateLocale(_locale *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		c.UpdateLocale(C.GoString(_locale))
		return C.CString("ok")
	})
}

//export addSplitTunnelItem
func addSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}

		filterType := C.GoString(filterTypeC)
		item := C.GoString(itemC)

		if err := c.AddSplitTunnelItem(filterType, item); err != nil {
			return C.CString(fmt.Sprintf("error adding item: %v", err))
		}
		slog.Debug("added split tunneling item", "filterType", filterType, "item", item)
		return nil
	})
}

//export removeSplitTunnelItem
func removeSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		filterType := C.GoString(filterTypeC)
		item := C.GoString(itemC)

		if err := c.RemoveSplitTunnelItem(filterType, item); err != nil {
			return C.CString(fmt.Sprintf("error removing item: %v", err))
		}
		slog.Debug("removed split tunneling item", "filterType", filterType, "item", item)
		return nil
	})
}

//export setSplitTunnelingEnabled
func setSplitTunnelingEnabled(enabled C.int) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if enabled != 0 {
			c.SetSplitTunnelingEnabled(true)
		} else {
			c.SetSplitTunnelingEnabled(false)
		}
		return C.CString("ok")
	})
}

//export isSplitTunnelingEnabled
func isSplitTunnelingEnabled() C.int {
	c, _ := requireCore()
	if c != nil && c.IsSplitTunnelingEnabled() {
		return 1
	}
	return 0
}

//export loadInstalledApps
func loadInstalledApps(dataDir *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		appsJson, err := c.LoadInstalledApps(C.GoString(dataDir))
		if err != nil {
			return C.CString(fmt.Sprintf("error loading installed apps: %v", err))
		}
		return C.CString(appsJson)
	})
}

//export getDataCapInfo
func getDataCapInfo() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		info, err := c.DataCapInfo()
		if err != nil {
			return SendError(err)
		}
		return C.CString(info)
	})
}

//export reportIssue
func reportIssue(emailC, typeC, descC, deviceC, modelC, logPathC *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		email := C.GoString(emailC)
		issueType := C.GoString(typeC)
		desc := C.GoString(descC)
		device := C.GoString(deviceC)
		model := C.GoString(modelC)
		logPath := C.GoString(logPathC)

		if err := c.ReportIssue(email, issueType, desc, device, model, logPath); err != nil {
			return C.CString(fmt.Sprintf("error reporting issue: %v", err))
		}

		slog.Debug(
			"Reported issue: %s – %s on %s/%s",
			email, issueType, device, model,
		)
		return C.CString("ok")
	})
}

// getAutoLocation returns the auto location in JSON format.
//
//export getAutoLocation
func getAutoLocation() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		location, err := vpn_tunnel.GetAutoLocation()
		if err != nil {
			return SendError(err)
		}

		// Use GetServerByTagJSON which marshals internally, avoiding GC write
		// barrier panics when pointer-rich Server types are copied on the CGo stack.
		jsonBytes, ok, err := c.GetServerByTagJSON(location.Lantern)
		if err != nil {
			return SendError(fmt.Errorf("error marshalling server: %v", err))
		}
		if !ok {
			return SendError(fmt.Errorf("error finding server with tag: %s", location.Lantern))
		}
		return C.CString(string(jsonBytes))
	})
}

// isTagAvailable checks if a server with the given tag exists in the server list.
// Returns "true" if found, "false" if not found, or "true" when the check cannot be
// performed (fail-open: allows connection attempts to proceed normally).
//
//export isTagAvailable
func isTagAvailable(_tag *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		tag := C.GoString(_tag)
		c, errStr := requireCore()
		if errStr != nil {
			slog.Warn("Unable to check tag availability (core not ready), assuming available", "tag", tag)
			C.free(unsafe.Pointer(errStr))
			return C.CString("true")
		}
		_, found, err := c.GetServerByTagJSON(tag)
		if err != nil {
			slog.Warn("Error checking tag availability, assuming available", "tag", tag, "error", err)
			return C.CString("true")
		}
		if found {
			return C.CString("true")
		}
		return C.CString("false")
	})
}

// startAutoLocationListener starts the auto location listener.
//
//export startAutoLocationListener
func startAutoLocationListener() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		c.StartBackgroundListeners()
		return C.CString("ok")
	})
}

// stopAutoLocationListener stops the auto location listener.
//
//export stopAutoLocationListener
func stopAutoLocationListener() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		c.StopBackgroundListeners()
		return C.CString("ok")
	})
}

// GetAvailableServers returns the available servers in JSON format.
//
//export getAvailableServers
func getAvailableServers() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		return C.CString(string(c.GetAvailableServers()))
	})
}

func sendStatusToPort(status VPNStatus) {
	slog.Debug("sendStatusToPort called", "status", status)
	if statusPort == 0 {
		slog.Error("Status port is not set, cannot send status")
		return
	}
	msg := map[string]any{"status": status}
	slog.Debug("Sending status to port", "port", statusPort)
	data, _ := json.Marshal(msg)
	slog.Debug("Marshalled status data", "data", string(data))
	dart_api_dl.SendToPort(statusPort, string(data))
	slog.Debug("Status sent to port successfully", "status", status)

}

// APIS
// Get user data from the local config
//
//export getUserData
func getUserData() *C.char {
	return runOnGoStack(func() *C.char {
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
	})
}

// Get user data from the server
//
//export fetchUserData
func fetchUserData() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("Getting user data")
		bytes, err := c.FetchUserData()
		if err != nil {
			return SendError(fmt.Errorf("error fetching user data: %v", err))
		}
		encoded := base64.StdEncoding.EncodeToString(bytes)
		return C.CString(encoded)
	})
}

// Fetch stipe subscription payment redirect link
//
//export stripeSubscriptionPaymentRedirect
func stripeSubscriptionPaymentRedirect(subType, _planId, _email *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("stripeSubscriptionPaymentRedirect called")
		subscriptionType := C.GoString(subType)
		planID := C.GoString(_planId)
		email := C.GoString(_email)
		slog.Debug("subscription type:", "subscriptionType", subscriptionType)
		redirect, err := c.StripeSubscriptionPaymentRedirect(subscriptionType, planID, email)
		if err != nil {
			return SendError(err)
		}
		slog.Debug("stripeSubscriptionPaymentRedirect response:", "redirect", redirect)
		return C.CString(redirect)
	})
}

// Fetch payment redirect link for providers like alipay
//
//export paymentRedirect
func paymentRedirect(_plan, _provider, _email *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		plan := C.GoString(_plan)
		provider := C.GoString(_provider)
		email := C.GoString(_email)

		redirect, err := c.PaymentRedirect(provider, plan, email)
		if err != nil {
			return SendError(err)
		}
		slog.Debug("PaymentRedirect response:", "redirect", redirect)
		return C.CString(redirect)
	})
}

// Fetch stripe subscription link
//
//export stripeBillingPortalUrl
func stripeBillingPortalUrl() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		url, err := c.StripeBillingPortalUrl()
		if err != nil {
			return SendError(err)
		}
		slog.Debug("StripeBillingPortalUrl response", "url", url)
		return C.CString(url)
	})
}

// Fetch plans from the server
//
//export plans
func plans() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("Getting plans")
		jsonData, err := c.Plans("non-store")
		if err != nil {
			return SendError(err)
		}
		return C.CString(jsonData)
	})
}

// OAuth methods
//
//export oauthLoginUrl
func oauthLoginUrl(_provider *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		url, err := c.OAuthLoginUrl(C.GoString(_provider))
		if err != nil {
			return SendError(err)
		}
		return C.CString(url)
	})
}

//export oAuthLoginCallback
func oAuthLoginCallback(_oAuthToken *C.char) *C.char {
	oAuthToken := C.GoString(_oAuthToken)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.OAuthLoginCallback(oAuthToken)
		if err != nil {
			return SendError(err)
		}
		return C.CString(base64.StdEncoding.EncodeToString(bytes))
	})
}

// User management
//
// login is called when the user logs in with email and password.
//
//export login
func login(_email, _password *C.char) *C.char {
	email, password := C.GoString(_email), C.GoString(_password)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.Login(email, password)
		if err != nil {
			return SendError(err)
		}
		return C.CString(base64.StdEncoding.EncodeToString(bytes))
	})
}

//export signup
func signup(_email, _password *C.char) *C.char {
	email, password := C.GoString(_email), C.GoString(_password)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SignUp(email, password); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export logout
func logout(_email *C.char) *C.char {
	email := C.GoString(_email)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.Logout(email)
		if err != nil {
			return SendError(err)
		}
		return C.CString(base64.StdEncoding.EncodeToString(bytes))
	})
}

// startRecoveryByEmail will send recovery code to the email
//
//export startRecoveryByEmail
func startRecoveryByEmail(_email *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.StartRecoveryByEmail(C.GoString(_email)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// Validate email recovery code
//
//export validateEmailRecoveryCode
func validateEmailRecoveryCode(_email, _code *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ValidateChangeEmailCode(C.GoString(_email), C.GoString(_code)); err != nil {
			return SendError(fmt.Errorf("invalid_code: %v", err))
		}
		return C.CString("ok")
	})
}

// Complete recovery by email
//
//export completeRecoveryByEmail
func completeRecoveryByEmail(_email, _newPassword, _code *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.CompleteRecoveryByEmail(C.GoString(_email), C.GoString(_newPassword), C.GoString(_code)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// removeDevice removes a device by its ID.
//
//export removeDevice
func removeDevice(deviceId *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if _, err := c.RemoveDevice(C.GoString(deviceId)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// referralAttachment attaches a referral code to the user's account.
//
//export referralAttachment
func referralAttachment(_referralCode *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ok, err := c.ReferralAttachment(C.GoString(_referralCode))
		if err != nil {
			return SendError(err)
		}
		if !ok {
			return SendError(fmt.Errorf("failed to get referral attachment"))
		}
		return C.CString("ok")
	})
}

// startChangeEmail initiates the process of changing the user's email address.
//
//export startChangeEmail
func startChangeEmail(_newEmail, _password *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.StartChangeEmail(C.GoString(_newEmail), C.GoString(_password)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// completeChangeEmail completes the process of changing the user's email address.
//
//export completeChangeEmail
func completeChangeEmail(_newEmail, _password, _code *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.CompleteChangeEmail(C.GoString(_newEmail), C.GoString(_password), C.GoString(_code)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// Delete account permanently
//
//export deleteAccount
func deleteAccount(_email, _password *C.char, _isSSO C.int) *C.char {
	email, password, isSSO := C.GoString(_email), C.GoString(_password), _isSSO != 0
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.DeleteAccount(email, password, isSSO)
		if err != nil {
			return SendError(err)
		}
		return C.CString(base64.StdEncoding.EncodeToString(bytes))
	})
}

// activationCode create subscription using activation code
//
//export activationCode
func activationCode(_email, _resellerCode *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ActivationCode(C.GoString(_email), C.GoString(_resellerCode)); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
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
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ffiEventListener := &ffiPrivateServerEventListener{}
		err := c.DigitalOceanPrivateServer(ffiEventListener)
		if err != nil {
			slog.Error("Error starting DigitalOcean private server flow:", "err", err)
			return SendError(err)
		}
		slog.Debug("DigitalOcean private server flow started successfully")
		return C.CString("ok")
	})
}

// googleCloudPrivateServer starts the Google Cloud private server flow.
//
//export googleCloudPrivateServer
func googleCloudPrivateServer() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ffiEventListener := &ffiPrivateServerEventListener{}
		err := c.GoogleCloudPrivateServer(ffiEventListener)
		if err != nil {
			return SendError(fmt.Errorf("Error starting Google Cloud private server flow: %v", err))
		}
		slog.Debug("Google Cloud private server flow started successfully")
		return C.CString("ok")
	})
}

// selectAccount selects the account for the private server.
//
//export selectAccount
func selectAccount(_account *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		account := C.GoString(_account)
		slog.Debug("Selecting account:", "account", account)
		if err := c.SelectAccount(account); err != nil {
			return SendError(fmt.Errorf("Error selecting account: %v", err))
		}
		slog.Debug("Account selected successfully:", "account", account)
		return C.CString("ok")
	})
}

// selectedProject selects the project for the private server.
//
//export selectProject
func selectProject(_project *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		project := C.GoString(_project)
		err := c.SelectProject(project)
		if err != nil {
			return SendError(fmt.Errorf("Error getting selected project: %v", err))
		}
		slog.Debug("Selected project:", "project", project)
		return C.CString("ok")
	})
}

// validateSession validates the session for the private server.
//
//export validateSession
func validateSession() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("Validating session")
		err := c.ValidateSession()
		if err != nil {
			return SendError(fmt.Errorf("Error validating session: %v", err))
		}
		slog.Debug("Session validated successfully")
		return C.CString("ok")
	})
}

// startDepolyment starts the deployment for the private server.
//
//export startDepolyment
func startDepolyment(_selectedLocation, _serverName *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		location := C.GoString(_selectedLocation)
		serverName := C.GoString(_serverName)

		slog.Debug("Starting deployment with location: %s and plan: %s", location, serverName)
		err := c.StartDeployment(location, serverName)
		if err != nil {
			return SendError(fmt.Errorf("Error starting deployment: %v", err))
		}
		slog.Debug("Deployment started successfully with location: %s and plan: %s", location, serverName)
		return C.CString("ok")
	})
}

// cancelDepolyment cancels the deployment for the private server.
//
//export cancelDepolyment
func cancelDepolyment() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("Cancelling deployment")
		if err := c.CancelDeployment(); err != nil {
			return SendError(fmt.Errorf("Error cancelling deployment: %v", err))
		}
		slog.Debug("Deployment cancelled successfully")
		return C.CString("ok")
	})
}

// addServerManagerInstance adds a server manager instance manually.
//
//export addServerManagerInstance
func addServerManagerInstance(_ip, _port, _accessToken, _tag *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ffiEventListener := &ffiPrivateServerEventListener{}
		ip := C.GoString(_ip)
		port := C.GoString(_port)
		accessToken := C.GoString(_accessToken)
		tag := C.GoString(_tag)

		err := c.AddServerManagerInstance(ip, port, accessToken, tag, ffiEventListener)
		if err != nil {
			return SendError(fmt.Errorf("Error adding server manager instance: %v", err))
		}
		slog.Debug("Server manager instance added successfully with IP: %s, Port: %s, AccessToken: %s, Tag: %s", ip, port, accessToken, tag)
		return C.CString("ok")
	})
}

// inviteToServerManagerInstance invites to the server manager instance.
//
//export inviteToServerManagerInstance
func inviteToServerManagerInstance(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ip := C.GoString(_ip)
		port := C.GoString(_port)
		accessToken := C.GoString(_accessToken)
		inviteName := C.GoString(_inviteName)
		slog.Debug("Inviting to server manager instance:", "ip", ip, "port", port, "inviteName", inviteName)
		invite, err := c.InviteToServerManagerInstance(ip, port, accessToken, inviteName)
		if err != nil {
			return SendError(fmt.Errorf("Error inviting to server manager instance: %v", err))
		}
		slog.Debug("Invite created successfully:", "invite", invite)
		return C.CString(invite)
	})
}

// revokeServerManagerInvite revokes the server manager invite.
//
//export revokeServerManagerInvite
func revokeServerManagerInvite(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ip := C.GoString(_ip)
		port := C.GoString(_port)
		accessToken := C.GoString(_accessToken)
		inviteName := C.GoString(_inviteName)
		slog.Debug("Revoking invite:", "inviteName", inviteName, "ip", ip, "port", port)
		err := c.RevokeServerManagerInvite(ip, port, accessToken, inviteName)
		if err != nil {
			return SendError(fmt.Errorf("Error revoking server manager invite: %v", err))
		}
		slog.Debug("Invite revoked successfully:", "inviteName", inviteName, "ip", ip, "port", port)
		return C.CString("ok")
	})
}

// addServerBasedOnURLs adds a server based on the provided URLs.
//
//export addServerBasedOnURLs
func addServerBasedOnURLs(_urls *C.char, _skipCertVerification C.int, _serverName *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		urls := C.GoString(_urls)
		skipCertVerification := _skipCertVerification != 0
		serverName := C.GoString(_serverName)
		slog.Debug("Adding server based on URLs:", "urls", urls, "skipCertVerification", skipCertVerification)
		err := c.AddServerBasedOnURLs(urls, skipCertVerification, serverName)
		if err != nil {
			return SendError(fmt.Errorf("Error adding server based on URLs: %v", err))
		}
		slog.Debug("Server added successfully based on URLs:", "urls", urls)
		return C.CString("ok")
	})
}

//export setBlockAdsEnabled
func setBlockAdsEnabled(enabled C.int) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SetBlockAdsEnabled(enabled != 0); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export isBlockAdsEnabled
func isBlockAdsEnabled() C.int {
	c, _ := requireCore()
	if c != nil && c.IsBlockAdsEnabled() {
		return 1
	}
	return 0
}

//export setSmartRoutingEnabled
func setSmartRoutingEnabled(enabled C.int) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SetSmartRoutingEnabled(enabled != 0); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export isSmartRoutingEnabled
func isSmartRoutingEnabled() C.int {
	c, _ := requireCore()
	if c != nil && c.IsSmartRoutingEnabled() {
		return 1
	}
	return 0
}

//export getSplitTunnelState
func getSplitTunnelState() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		s, err := c.GetSplitTunnelStateJSON()
		if err != nil {
			return SendError(err)
		}
		return C.CString(s)
	})
}

//export getSplitTunnelItems
func getSplitTunnelItems(filterTypeC *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		filterType := C.GoString(filterTypeC)
		s, err := c.GetSplitTunnelItems(filterType)
		if err != nil {
			return SendError(err)
		}
		return C.CString(s)
	})
}

//export deletePrivateServerByName
func deletePrivateServerByName(_name *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		name := C.GoString(_name)
		if err := c.DeleteServer(name); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export updatePrivateServerName
func updatePrivateServerName(_oldName, _newName *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		oldName := C.GoString(_oldName)
		newName := C.GoString(_newName)
		if err := c.UpdatePrivateServerName(oldName, newName); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export getAppDataDir
func getAppDataDir() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		return C.CString(c.GetAppDataDir())
	})
}

//export getEnabledApps
func getEnabledApps() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		s, err := c.GetEnabledApps()
		if err != nil {
			return SendError(err)
		}
		return C.CString(s)
	})
}
