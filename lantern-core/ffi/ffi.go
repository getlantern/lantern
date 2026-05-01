//go:build !android && !ios && !macos

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
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"

	lanterncore "github.com/getlantern/lantern/lantern-core"
	"github.com/getlantern/lantern/lantern-core/apps"
	"github.com/getlantern/lantern/lantern-core/dart_api_dl"
	"github.com/getlantern/lantern/lantern-core/logs"
	"github.com/getlantern/lantern/lantern-core/utils"

	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/vpn"
)

// runOnGoStack wraps utils.RunOffCgoStack for FFI functions that return *C.char.
// CGo-exported functions run on a callback stack whose memory isn't tracked
// by the GC heap bitmap. Allocating Go pointers (like C.CString) on that stack
// triggers bulkBarrierPreWrite panics.
func runOnGoStack(fn func() *C.char) *C.char {
	result, _ := utils.RunOffCgoStack(func() (*C.char, error) {
		return fn(), nil
	})
	return result
}

const (
	enableLogging = false
)

var (
	lanternCore       atomic.Pointer[lanterncore.Core]
	appDataDir        string
	appsPort          atomic.Int64
	logsPort          atomic.Int64
	statusPort        atomic.Int64
	privateserverPort atomic.Int64
	appEventPort      atomic.Int64
)

func requireCore() (lanterncore.Core, *C.char) {
	c := lanternCore.Load()
	if c == nil {
		return nil, C.CString(`{"error":"not_initialized"}`)
	}
	return *c, nil
}

//export getAppDataDir
func getAppDataDir() *C.char {
	return runOnGoStack(func() *C.char {
		return C.CString(appDataDir)
	})
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
	port := appEventPort.Load()
	if port == 0 {
		slog.Error("Apps port is not set, cannot send event")
		return
	}
	eventData, err := json.Marshal(event)
	if err != nil {
		slog.Error("Error marshalling event:", "error", err)
		return
	}
	slog.Debug("Marshalled event data:", "data", string(eventData))
	go dart_api_dl.SendToPort(port, string(eventData))
}

//export setup
func setup(_logDir, _dataDir, _locale, _env *C.char, logP, appsP, statusP, privateServerP, appEventP C.int64_t, consent C.int, api unsafe.Pointer) *C.char {
	logDir := C.GoString(_logDir)
	dataDir := C.GoString(_dataDir)
	appDataDir = dataDir
	locale := C.GoString(_locale)
	env := C.GoString(_env)
	return runOnGoStack(func() *C.char {
		core, err := lanterncore.New(&utils.Opts{
			LogDir:           logDir,
			DataDir:          dataDir,
			Locale:           locale,
			Env:              env,
			Deviceid:         "",
			LogLevel:         lanterncore.DefaultLogLevel,
			TelemetryConsent: consent == 1,
		}, &ffiFlutterEventEmitter{})

		if err != nil {
			return C.CString(fmt.Sprintf("unable to create LanternCore: %v", err))
		}
		dart_api_dl.Init(api)
		lanternCore.Store(&core)
		logsPort.Store(int64(logP))
		appsPort.Store(int64(appsP))
		statusPort.Store(int64(statusP))
		privateserverPort.Store(int64(privateServerP))
		appEventPort.Store(int64(appEventP))

		// Start the VPN status listener immediately so the UI reflects the
		// current VPN state even if the VPN was already connected (e.g. macOS
		// system extension started before the Flutter app).
		startStatusListener(core)
		startLogsListener(core)

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
		if err := c.UpdateTelemetryConsent(consent != 0); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export isTelemetryEnabled
func isTelemetryEnabled() C.int {
	c, _ := requireCore()
	if c != nil && c.IsTelemetryEnabled() {
		return 1
	}
	return 0
}

//export isOAuthLogin
func isOAuthLogin() C.int {
	c, _ := requireCore()
	if c != nil && c.IsOAuthLogin() {
		return 1
	}
	return 0
}

//export getOAuthProvider
func getOAuthProvider() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		return C.CString(c.GetOAuthProvider())
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
	locale := C.GoString(_locale)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		c.UpdateLocale(locale)
		return C.CString("ok")
	})
}

//export addSplitTunnelItem
func addSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.AddSplitTunnelItem(filterType, item); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export removeSplitTunnelItem
func removeSplitTunnelItem(filterTypeC, itemC *C.char) *C.char {
	filterType := C.GoString(filterTypeC)
	item := C.GoString(itemC)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.RemoveSplitTunnelItem(filterType, item); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export setSplitTunnelingEnabled
func setSplitTunnelingEnabled(enabled C.int) *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SetSplitTunnelingEnabled(enabled != 0); err != nil {
			return SendError(err)
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
	dir := C.GoString(dataDir)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		appsJson, err := c.LoadInstalledApps(dir)
		if err != nil {
			return C.CString(fmt.Sprintf("error loading installed apps: %v", err))
		}
		return C.CString(appsJson)
	})
}

//export loadInstalledAppIcon
func loadInstalledAppIcon(appPathC, iconPathC *C.char) *C.char {
	return runOnGoStack(func() *C.char {
		appPath := C.GoString(appPathC)
		iconPath := C.GoString(iconPathC)
		if appPath == "" && iconPath == "" {
			return C.CString("")
		}

		iconBytes, err := apps.LoadAppIconBytes(appPath, iconPath)
		if err != nil || len(iconBytes) == 0 {
			return C.CString("")
		}
		return C.CString(base64.StdEncoding.EncodeToString(iconBytes))
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
	email := C.GoString(emailC)
	issueType := C.GoString(typeC)
	desc := C.GoString(descC)
	device := C.GoString(deviceC)
	model := C.GoString(modelC)
	logPath := C.GoString(logPathC)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ReportIssue(email, issueType, desc, device, model, logPath); err != nil {
			return C.CString(fmt.Sprintf("error reporting issue: %v", err))
		}
		return C.CString("ok")
	})
}

// getSelectedServerJSON returns the selected server response as raw JSON.
//
//export getSelectedServerJSON
func getSelectedServerJSON() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		data, err := c.GetSelectedServerJSON()
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(data))
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
		data, err := c.GetAutoLocationJSON()
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(data))
	})
}

// isTagAvailable checks if a server with the given tag exists in the server list.
// Returns "true" if found, "false" if not found, or "true" when the check cannot be
// performed (fail-open: allows connection attempts to proceed normally).
//
//export isTagAvailable
func isTagAvailable(_tag *C.char) *C.char {
	tag := C.GoString(_tag)
	return runOnGoStack(func() *C.char {
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

func sendStatusToPort(status vpn.VPNStatus, errMsg string) {
	slog.Debug("sendStatusToPort called", "status", status)
	port := statusPort.Load()
	if port == 0 {
		slog.Error("Status port is not set, cannot send status")
		return
	}
	msg := map[string]any{"status": status}
	if errMsg != "" {
		msg["error"] = errMsg
	}
	slog.Debug("Sending status to port", "port", port)
	data, _ := json.Marshal(msg)
	slog.Debug("Marshalled status data", "data", string(data))
	dart_api_dl.SendToPort(port, string(data))
	slog.Debug("Status sent to port successfully", "status", status)
}

var (
	statusListenerOnce   sync.Once
	statusListenerLastMu sync.Mutex
	statusListenerLast   string
)

// startStatusListener subscribes to radiance's VPN status SSE stream and
// forwards status changes to Flutter via the Dart status port.
func startStatusListener(c lanterncore.Core) {
	statusListenerOnce.Do(func() {
		go func() {
			for {
				if statusPort.Load() == 0 {
					time.Sleep(100 * time.Millisecond)
					continue
				}
				c.VPNStatusEvents(context.Background(), func(evt vpn.StatusUpdateEvent) {
					status, errMsg := mapStatusEvent(evt)

					statusListenerLastMu.Lock()
					changed := string(status) != statusListenerLast
					if changed {
						statusListenerLast = string(status)
					}
					statusListenerLastMu.Unlock()

					if changed {
						// [vpn-state-trace] hop=ffi_to_port — moment lantern-core forwards
						// the parsed status to the Dart ReceivePort. The gap to dart_applied
						// measures Dart isolate scheduling + Riverpod notify on Windows.
						slog.Info("[vpn-state-trace]", "hop", "ffi_to_port", "status", status, "ts_ms", time.Now().UnixMilli())
						sendStatusToPort(status, errMsg)
					}
				})
				// SSE stream disconnected — retry after a short delay.
				time.Sleep(500 * time.Millisecond)
			}
		}()
	})
}

var logsListenerOnce sync.Once

// startLogsListener subscribes to radiance's log SSE stream and forwards each
// entry to Flutter via the Dart logs port.
func startLogsListener(c lanterncore.Core) {
	logsListenerOnce.Do(func() {
		go func() {
			for {
				port := logsPort.Load()
				if port == 0 {
					time.Sleep(100 * time.Millisecond)
					continue
				}
				err := logs.Subscribe(context.Background(), c.Client(), func(entry string) {
					dart_api_dl.SendToPort(logsPort.Load(), entry)
				})
				if err != nil {
					slog.Debug("log stream disconnected", "error", err)
				}
				time.Sleep(500 * time.Millisecond)
			}
		}()
	})
}

// mapStatusEvent normalizes a radiance VPN status event for forwarding to
// Dart. Most values pass through unchanged; the exceptions are:
//   - vpn.Restarting collapses into vpn.Connecting so the UI shows a
//     transitional state during a tunnel restart rather than an unknown
//     "restarting" string the Dart parser falls back to disconnected on.
//   - A non-empty evt.Error always maps to vpn.ErrorStatus (radiance also
//     emits ErrorStatus in this case, but be explicit so the contract
//     doesn't depend on radiance always agreeing).
//   - An unrecognized status falls back to Disconnected so the UI never
//     gets stuck on a stale connected indicator.
func mapStatusEvent(evt vpn.StatusUpdateEvent) (vpn.VPNStatus, string) {
	if evt.Error != "" {
		return vpn.ErrorStatus, evt.Error
	}
	switch evt.Status {
	case vpn.Connected, vpn.Connecting, vpn.Disconnecting, vpn.Disconnected, vpn.ErrorStatus:
		return evt.Status, ""
	case vpn.Restarting:
		return vpn.Connecting, ""
	default:
		return vpn.Disconnected, ""
	}
}

//export startVPN
func startVPN() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		startStatusListener(c)

		if err := checkDaemonReachable(c); err != nil {
			return C.CString(err.Error())
		}

		if err := c.ConnectVPN(""); err != nil {
			return C.CString(fmt.Sprintf("start service failed: %v", err))
		}

		return C.CString("ok")
	})
}

//export stopVPN
func stopVPN() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}

		if err := c.DisconnectVPN(); err != nil {
			return C.CString(fmt.Sprintf("stop service failed: %v", err))
		}

		return C.CString("ok")
	})
}

//export connectToServer
func connectToServer(_tag *C.char) *C.char {
	tag := C.GoString(_tag)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		startStatusListener(c)

		if err := checkDaemonReachable(c); err != nil {
			return SendError(err)
		}

		// LanternCore.ConnectVPN picks between /vpn/connect and /server/selected
		// based on VPNStatus — no dispatch needed here.
		if err := c.ConnectVPN(tag); err != nil {
			return SendError(fmt.Errorf("start service failed: %w", err))
		}
		return C.CString("ok")
	})
}

//export isVPNConnected
func isVPNConnected() C.int {
	c, errStr := requireCore()
	if errStr != nil {
		return 0
	}

	running, err := c.IsVPNRunning()
	if err != nil {
		return 0
	}
	if running {
		return 1
	}
	return 0
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
		return C.CString(string(bytes))
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
		return C.CString(string(bytes))
	})
}

// Fetch stipe subscription payment redirect link
//
//export stripeSubscriptionPaymentRedirect
func stripeSubscriptionPaymentRedirect(subType, _planId, _email *C.char) *C.char {
	subscriptionType := C.GoString(subType)
	planID := C.GoString(_planId)
	email := C.GoString(_email)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		redirect, err := c.StripeSubscriptionPaymentRedirect(subscriptionType, planID, email)
		if err != nil {
			return SendError(err)
		}
		return C.CString(redirect)
	})
}

// Fetch payment redirect link for providers like alipay
//
//export paymentRedirect
func paymentRedirect(_plan, _provider, _email *C.char) *C.char {
	plan := C.GoString(_plan)
	provider := C.GoString(_provider)
	email := C.GoString(_email)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		redirect, err := c.PaymentRedirect(provider, plan, email)
		if err != nil {
			return SendError(err)
		}
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
	provider := C.GoString(_provider)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		url, err := c.OAuthLoginUrl(provider)
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
		return C.CString(string(bytes))
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
		return C.CString(string(bytes))
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
		return C.CString(string(bytes))
	})
}

// startRecoveryByEmail will send recovery code to the email
//
//export startRecoveryByEmail
func startRecoveryByEmail(_email *C.char) *C.char {
	email := C.GoString(_email)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.StartRecoveryByEmail(email); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// Validate email recovery code
//
//export validateEmailRecoveryCode
func validateEmailRecoveryCode(_email, _code *C.char) *C.char {
	email, code := C.GoString(_email), C.GoString(_code)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ValidateChangeEmailCode(email, code); err != nil {
			return SendError(fmt.Errorf("invalid_code: %v", err))
		}
		return C.CString("ok")
	})
}

// Complete recovery by email
//
//export completeRecoveryByEmail
func completeRecoveryByEmail(_email, _newPassword, _code *C.char) *C.char {
	email, newPassword, code := C.GoString(_email), C.GoString(_newPassword), C.GoString(_code)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.CompleteRecoveryByEmail(email, newPassword, code); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// removeDevice removes a device by its ID.
//
//export removeDevice
func removeDevice(deviceId *C.char) *C.char {
	id := C.GoString(deviceId)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if _, err := c.RemoveDevice(id); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// referralAttachment attaches a referral code to the user's account.
//
//export referralAttachment
func referralAttachment(_referralCode *C.char) *C.char {
	referralCode := C.GoString(_referralCode)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		ok, err := c.ReferralAttachment(referralCode)
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
	newEmail, password := C.GoString(_newEmail), C.GoString(_password)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.StartChangeEmail(newEmail, password); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// completeChangeEmail completes the process of changing the user's email address.
//
//export completeChangeEmail
func completeChangeEmail(_newEmail, _password, _code *C.char) *C.char {
	newEmail, password, code := C.GoString(_newEmail), C.GoString(_password), C.GoString(_code)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.CompleteChangeEmail(newEmail, password, code); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// Delete account permanently
//
//export deleteAccount
func deleteAccount(_email, _password *C.char) *C.char {
	email, password := C.GoString(_email), C.GoString(_password)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.DeleteAccount(email, password)
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(bytes))
	})
}

// activationCode create subscription using activation code
//
//export activationCode
func activationCode(_email, _resellerCode *C.char) *C.char {
	email, resellerCode := C.GoString(_email), C.GoString(_resellerCode)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ActivationCode(email, resellerCode); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export freeCString
func freeCString(cstr *C.char) {
	C.free(unsafe.Pointer(cstr))
}

// patchSettings applies a JSON-encoded settings.Settings patch on the daemon.
//
//export patchSettings
func patchSettings(patchJSON *C.char) *C.char {
	raw := C.GoString(patchJSON)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		var updates settings.Settings
		if err := json.Unmarshal([]byte(raw), &updates); err != nil {
			return SendError(fmt.Errorf("invalid settings JSON: %w", err))
		}
		if err := c.PatchSettings(updates); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// getSettings returns the daemon's current settings as JSON.
//
//export getSettings
func getSettings() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		data, err := c.GetSettingsJSON()
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(data))
	})
}

// patchEnvVars applies a JSON-encoded map[string]string patch on the daemon's
// in-memory env vars. Returns the resulting env map as JSON.
//
//export patchEnvVars
func patchEnvVars(patchJSON *C.char) *C.char {
	raw := C.GoString(patchJSON)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		var updates map[string]string
		if err := json.Unmarshal([]byte(raw), &updates); err != nil {
			return SendError(fmt.Errorf("invalid env JSON: %w", err))
		}
		result, err := c.PatchEnvVars(updates)
		if err != nil {
			return SendError(err)
		}
		data, err := json.Marshal(result)
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(data))
	})
}

// getEnvVars returns the daemon's in-memory env vars as JSON.
//
//export getEnvVars
func getEnvVars() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		data, err := json.Marshal(c.GetEnvVars())
		if err != nil {
			return SendError(err)
		}
		return C.CString(string(data))
	})
}

//export runURLTests
func runURLTests() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.RunOfflineURLTests(); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export updateConfig
func updateConfig() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.UpdateConfig(); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
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
	// err may already be JSON (from convertErrorToJSON) or a raw string.
	// Ensure we always send valid JSON so the Dart jsonDecode doesn't crash.
	if !json.Valid([]byte(err)) {
		wrapped := map[string]string{"status": "error", "error": err}
		data, _ := json.Marshal(wrapped)
		sendPrivateServerEvent(string(data))
		return
	}
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
	port := privateserverPort.Load()
	if port == 0 {
		slog.Error("Private server port is not set, cannot send event")
		return
	}

	go func() {
		dart_api_dl.SendToPort(port, event)
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
		if err := c.DigitalOceanPrivateServer(&ffiPrivateServerEventListener{}); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export googleCloudPrivateServer
func googleCloudPrivateServer() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.GoogleCloudPrivateServer(&ffiPrivateServerEventListener{}); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export selectAccount
func selectAccount(_account *C.char) *C.char {
	account := C.GoString(_account)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SelectAccount(account); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export selectProject
func selectProject(_project *C.char) *C.char {
	project := C.GoString(_project)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.SelectProject(project); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export validateSession
func validateSession() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.ValidateSession(); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export startDepolyment
func startDepolyment(_selectedLocation, _serverName *C.char) *C.char {
	location := C.GoString(_selectedLocation)
	serverName := C.GoString(_serverName)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.StartDeployment(location, serverName); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export cancelDepolyment
func cancelDepolyment() *C.char {
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.CancelDeployment(); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export addServerManagerInstance
func addServerManagerInstance(_ip, _port, _accessToken, _tag *C.char) *C.char {
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	tag := C.GoString(_tag)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.AddServerManagerInstance(ip, port, accessToken, tag, &ffiPrivateServerEventListener{}); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export inviteToServerManagerInstance
func inviteToServerManagerInstance(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	inviteName := C.GoString(_inviteName)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		invite, err := c.InviteToServerManagerInstance(ip, port, accessToken, inviteName)
		if err != nil {
			return SendError(err)
		}
		return C.CString(invite)
	})
}

//export revokeServerManagerInvite
func revokeServerManagerInvite(_ip, _port, _accessToken, _inviteName *C.char) *C.char {
	ip := C.GoString(_ip)
	port := C.GoString(_port)
	accessToken := C.GoString(_accessToken)
	inviteName := C.GoString(_inviteName)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.RevokeServerManagerInvite(ip, port, accessToken, inviteName); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

// addServerBasedOnURLs adds a server based on the provided URLs.
//
//export addServerBasedOnURLs
func addServerBasedOnURLs(_urls *C.char, _skipCertVerification C.int) *C.char {
	urls := C.GoString(_urls)
	skipCertVerification := _skipCertVerification != 0
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		slog.Debug("Adding server based on URLs:", "urls", urls, "skipCertVerification", skipCertVerification)
		bytes, err := c.AddServersByURL(urls, skipCertVerification)
		if err != nil {
			return SendError(fmt.Errorf("Error adding server based on URLs: %v", err))
		}
		return C.CString(string(bytes))
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
		s, err := c.GetSplitTunnelItems()
		if err != nil {
			return SendError(err)
		}
		return C.CString(s)
	})
}

//export getSplitTunnelItems
func getSplitTunnelItems(filterTypeC *C.char) *C.char {
	filterType := C.GoString(filterTypeC)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		bytes, err := c.GetSplitTunnelItemsFor(filterType)
		if err != nil {
			return SendError(err)
		}
		return C.CString(bytes)
	})
}

//export deletePrivateServerByName
func deletePrivateServerByName(_name *C.char) *C.char {
	name := C.GoString(_name)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.DeleteServer(name); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
	})
}

//export updatePrivateServerName
func updatePrivateServerName(_oldName, _newName *C.char) *C.char {
	oldName := C.GoString(_oldName)
	newName := C.GoString(_newName)
	return runOnGoStack(func() *C.char {
		c, errStr := requireCore()
		if errStr != nil {
			return errStr
		}
		if err := c.UpdatePrivateServerName(oldName, newName); err != nil {
			return SendError(err)
		}
		return C.CString("ok")
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
