package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"sync"
	"sync/atomic"
	"time"

	_ "golang.org/x/mobile/bind"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/ipc"

	lanterncore "github.com/getlantern/lantern/lantern-core"
	"github.com/getlantern/lantern/lantern-core/logs"
	"github.com/getlantern/lantern/lantern-core/utils"
	"github.com/getlantern/lantern/lantern-core/vpn_tunnel"
)

var (
	lanternCore        atomic.Value
	errLanternNotReady = errors.New("radiance not initialized")

	ipcServer  *ipc.Server
	ipcClient  *ipc.Client // loopback client for extension process
	ipcBackend *backend.LocalBackend
	ipcMu      sync.Mutex
	ipcOnce    sync.Once
)

func getCore() (lanterncore.Core, error) {
	v := lanternCore.Load()
	if v == nil {
		return nil, errLanternNotReady
	}
	return v.(lanterncore.Core), nil
}

// withCore is a helper function that provides access to the lanterncore.Core instance.
// It runs fn on a real Go goroutine via RunOffCgoStack to avoid GC write barrier
// panics when gomobile-exported functions are called from CGo callback stacks.
func withCore(fn func(c lanterncore.Core) error) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		c, err := getCore()
		if err != nil {
			return struct{}{}, err
		}
		return struct{}{}, fn(c)
	})
	return err
}

// withCoreR is a helper function that provides type-safe access to the lanterncore.Core instance.
// It runs fn on a real Go goroutine via RunOffCgoStack to avoid GC write barrier
// panics when gomobile-exported functions are called from CGo callback stacks.
func withCoreR[T any](fn func(c lanterncore.Core) (T, error)) (T, error) {
	return utils.RunOffCgoStack(func() (T, error) {
		c, err := getCore()
		if err != nil {
			var zero T
			return zero, err
		}
		return fn(c)
	})
}

// getClient returns an IPC client. It prefers the loopback client created by
// StartIPCServer (extension process), falling back to lanternCore's client
// (main app process).
func getClient() (*ipc.Client, error) {
	ipcMu.Lock()
	c := ipcClient
	ipcMu.Unlock()
	if c != nil {
		return c, nil
	}
	core, err := getCore()
	if err != nil {
		return nil, err
	}
	return core.Client(), nil
}

// SetQAEnvOverrides applies QA-only environment overrides before Radiance starts.
func SetQAEnvOverrides(outboundSocks, tz string) error {
	if outboundSocks != "" {
		if err := os.Setenv("RADIANCE_OUTBOUND_SOCKS_ADDRESS", outboundSocks); err != nil {
			return fmt.Errorf("set RADIANCE_OUTBOUND_SOCKS_ADDRESS: %w", err)
		}
		slog.Info("QA env override set", "name", "RADIANCE_OUTBOUND_SOCKS_ADDRESS", "value", outboundSocks)
	}
	if tz != "" {
		if err := os.Setenv("TZ", tz); err != nil {
			return fmt.Errorf("set TZ: %w", err)
		}
		slog.Info("QA env override set", "name", "TZ", "value", tz)
	}
	return nil
}

// InitLogging wires the global slog handler (file + stdout) before any other
// Mobile.* call. On Android the entire app runs in a single process, so once
// common.Init runs `slog.SetDefault` covers all Go code — but it normally
// only runs deep inside SetupRadiance / StartIPCServer, which the Android
// side launches asynchronously from LanternVpnService after an intent. Any
// lantern-core or radiance log emitted in the meantime (Flutter MethodChannel
// handlers reach a wide surface before the VPN service is up) falls through
// to the stdlib default — text → stderr → logcat at INFO — so debug logs
// vanish and the format diverges from the rest. Calling this from
// MainActivity.configureFlutterEngine before startLanternService closes that
// gap.
//
// The first call wins: dataDir/logDir/logLevel here are what take effect.
// Pass the same values that the later backend.NewLocalBackend → common.Init
// will see (in practice both derive from LanternVpnService.opts()), otherwise
// the early values silently override.
func InitLogging(dataDir, logDir, logLevel string) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		return struct{}{}, common.Init(dataDir, logDir, logLevel)
	})
	return err
}

func SetupRadiance(opts *utils.Opts, eventEmitter utils.FlutterEventEmitter) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		slog.Info("Setting up Radiance", "opts", opts)
		c, err := lanterncore.New(opts, eventEmitter)
		if err != nil {
			return struct{}{}, fmt.Errorf("unable to create LanternCore: %v", err)
		}
		lanternCore.Store(c)
		return struct{}{}, nil
	})
	return err
}

func UpdateTelemetryConsent(consent bool) error {
	slog.Info("telemetry: UpdateTelemetryConsent", "consent", consent)
	return withCore(func(c lanterncore.Core) error {
		return c.UpdateTelemetryConsent(consent)
	})
}

func IsTelemetryEnabled() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsTelemetryEnabled(), nil
	})
	if err != nil {
		return false
	}
	return ok
}

func IsOAuthLogin() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsOAuthLogin(), nil
	})
	if err != nil {
		return false
	}
	return ok
}

func GetOAuthProvider() string {
	provider, err := withCoreR(func(c lanterncore.Core) (string, error) {
		return c.GetOAuthProvider(), nil
	})
	if err != nil {
		return ""
	}
	return provider
}

func SetBlockAdsEnabled(enabled bool) error {
	slog.Info("adblock: SetBlockAdsEnabled", "enabled", enabled)
	return withCore(func(c lanterncore.Core) error {
		return c.SetBlockAdsEnabled(enabled)
	})
}

func IsBlockAdsEnabled() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsBlockAdsEnabled(), nil
	})
	if err != nil {
		return false
	}
	return ok
}

func SetSmartRoutingEnabled(enabled bool) error {
	slog.Info("smart-routing: SetSmartRoutingEnabled", "enabled", enabled)
	return withCore(func(c lanterncore.Core) error {
		return c.SetSmartRoutingEnabled(enabled)
	})
}

func IsSmartRoutingEnabled() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsSmartRoutingEnabled(), nil
	})
	if err != nil {
		return false
	}
	return ok
}

// AvailableFeatures returns feature-flag data as a JSON string.
//
// Returns string (not []byte) so the gomobile wrapper marshals the return value
// via C.malloc rather than leaving it as a Go slice header. This avoids a
// runtime.bulkBarrierPreWrite panic on the cgo callback goroutine during GC
// (see getlantern/engineering#3175).
func AvailableFeatures() string {
	s, err := withCoreR(func(c lanterncore.Core) (string, error) { return string(c.AvailableFeatures()), nil })
	if err != nil {
		return `{}`
	}
	return s
}

func MyDeviceId() (string, error) {
	id, err := withCoreR(func(c lanterncore.Core) (string, error) { return c.MyDeviceId(), nil })
	if err != nil {
		return "", err
	}
	return id, nil
}

func UpdateLocale(locale string) error {
	return withCore(func(c lanterncore.Core) error { return c.UpdateLocale(locale) })
}

func IsRadianceConnected() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) { return c.IsRadianceConnected(), nil })
	if err != nil {
		return false
	}
	return ok
}

func StartVPN() error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		slog.Info("Starting VPN")
		client, err := getClient()
		if err != nil {
			return struct{}{}, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		if err := vpn_tunnel.StartVPN(ctx, client); err != nil {
			return struct{}{}, err
		}
		return struct{}{}, nil
	})
	return err
}

func StopVPN() error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		slog.Info("Stopping VPN")
		client, err := getClient()
		if err != nil {
			return struct{}{}, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := vpn_tunnel.StopVPN(ctx, client); err != nil {
			return struct{}{}, err
		}
		return struct{}{}, nil
	})
	return err
}

func StartIPCServer(platform utils.PlatformInterface, opts *utils.Opts) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		ipcMu.Lock()
		defer ipcMu.Unlock()
		if ipcServer != nil {
			return struct{}{}, nil
		}
		bopts := backend.Options{
			DataDir:           opts.DataDir,
			LogDir:            opts.LogDir,
			Locale:            opts.Locale,
			LogLevel:          opts.LogLevel,
			DeviceID:          opts.Deviceid,
			TelemetryConsent:  opts.TelemetryConsent,
			PlatformInterface: platform,
		}
		be, err := backend.NewLocalBackend(context.Background(), bopts)
		if err != nil {
			return struct{}{}, fmt.Errorf("error creating backend for IPC server: %v", err)
		}
		be.Start()
		ipcBackend = be
		ipcServer = ipc.NewServer(be, !common.IsMobile())
		ipcClient = newLoopbackClient(be)
		return struct{}{}, ipcServer.Start()
	})
	return err
}

func CloseIPCServer() error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		ipcMu.Lock()
		defer ipcMu.Unlock()
		if ipcBackend != nil {
			ipcBackend.Close()
			ipcBackend = nil
		}
		if ipcServer != nil {
			ipcServer.Close()
			ipcServer = nil
		}
		ipcClient = nil
		return struct{}{}, nil
	})
	return err
}

// IsTagAvailable checks if a server with the given tag exists in the server list.
// Returns true if the tag is found. Returns true when the check cannot be performed
// (fail-open: allows connection attempts to proceed normally).
func IsTagAvailable(tag string) bool {
	found, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		_, ok, err := c.GetServerByTagJSON(tag)
		return ok, err
	})
	if err != nil {
		slog.Warn("Unable to check tag availability, assuming available", "tag", tag, "error", err)
		return true
	}
	return found
}

// ConnectToServer connects to a server using the provided location type and tag.
// It works with private servers and lantern location servers.
func ConnectToServer(tag string) error {
	_, err := utils.RunOffCgoStack(func() (struct{}, error) {
		client, err := getClient()
		if err != nil {
			return struct{}{}, err
		}
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		if err := vpn_tunnel.ConnectToServer(ctx, client, tag); err != nil {
			return struct{}{}, err
		}
		return struct{}{}, nil
	})
	return err
}

// GetAvailableServers returns the available servers in JSON format.
//
// Returns string (not []byte) — see AvailableFeatures for the rationale.
func GetAvailableServers() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return string(c.GetAvailableServers()), nil
	})
}

func IsVPNConnected() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) {
		return c.IsVPNRunning()
	})
	if err != nil {
		return false
	}
	return ok
}

func GetSelectedServer() string {
	s, err := withCoreR(func(c lanterncore.Core) (string, error) {
		return c.GetSelectedServerTag()
	})
	if err != nil {
		return ""
	}
	return s
}

func GetSelectedServerJSON() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.GetSelectedServerJSON()
		return string(b), err
	})
}

func GetAutoLocation() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		data, err := c.GetAutoLocationJSON()
		if err != nil {
			return "", err
		}
		slog.Debug("Auto location server:", "server", string(data))
		return string(data), nil
	})
}

// Split Tunnel Methods
func AddSplitTunnelItem(filterType, item string) error {
	return withCore(func(c lanterncore.Core) error { return c.AddSplitTunnelItem(filterType, item) })
}

func RemoveSplitTunnelItem(filterType, item string) error {
	return withCore(func(c lanterncore.Core) error { return c.RemoveSplitTunnelItem(filterType, item) })
}

func AddSplitTunnelItems(items string) error {
	return withCore(func(c lanterncore.Core) error { return c.AddSplitTunnelItems(items) })
}

func RemoveSplitTunnelItems(items string) error {
	return withCore(func(c lanterncore.Core) error { return c.RemoveSplitTunnelItems(items) })
}

func SetSplitTunnelingEnabled(enabled bool) error {
	return withCore(func(c lanterncore.Core) error { return c.SetSplitTunnelingEnabled(enabled) })
}

func IsSplitTunnelingEnabled() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) { return c.IsSplitTunnelingEnabled(), nil })
	if err != nil {
		return false
	}
	return ok
}

func ReportIssue(
	email, issueType, description, device, model, logFilePath, attachmentsJSON string,
) error {
	return withCore(func(c lanterncore.Core) error {
		return c.ReportIssue(
			email,
			issueType,
			description,
			device,
			model,
			logFilePath,
			attachmentsJSON,
		)
	})
}

func LoadInstalledApps(dataDir string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return c.LoadInstalledApps(dataDir)
	})
}

// User Methods
// UserData returns pre-fetched user data.
func UserData() (string, error) {
	slog.Debug("User data")
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.UserData()
		return string(b), err
	})
}

// FetchUserData will get the user data from the server
func FetchUserData() (string, error) {
	slog.Debug("Fetching user data")
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.FetchUserData()
		return string(b), err
	})
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.OAuthLoginUrl(provider) })
}

func OAuthLoginCallback(oAuthToken string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.OAuthLoginCallback(oAuthToken)
		return string(b), err
	})
}

func StripeSubscription(email, planID string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.StripeSubscription(email, planID) })
}

func Plans(channel string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.Plans(channel) })
}
func StripeBillingPortalUrl() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.StripeBillingPortalUrl() })
}

func AcknowledgeGooglePurchase(purchaseToken, planId string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		data, err := c.AcknowledgeGooglePurchase(purchaseToken, planId)
		if err != nil {
			return "", err
		}
		var resp account.VerifySubscriptionResponse
		if err := json.Unmarshal([]byte(data), &resp); err != nil {
			return "", fmt.Errorf("error unmarshalling acknowledge google purchase response: %v", err)
		}

		if resp.ActualUserID != 0 && resp.ActualUserToken != "" {
			/// This means the purchase was made on a different account and we need to switch to that account
			slog.Info("Purchase made on a different account, switching accounts", "actualUserId", resp.ActualUserID)
			if err := c.PatchSettings(settings.Settings{
				settings.UserIDKey: fmt.Sprintf("%d", resp.ActualUserID),
				settings.TokenKey:  resp.ActualUserToken,
			}); err != nil {
				return "", fmt.Errorf("error updating settings after account switch: %v", err)
			}
			userData, err := FetchUserData()
			if err != nil {
				return "", err
			}
			return userData, nil
		}
		/// Purchase was made on the same account, just return "" to indicate success
		return "", nil

	})
}

func AcknowledgeApplePurchase(receipt, planII string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		data, err := c.AcknowledgeApplePurchase(receipt, planII)
		if err != nil {
			return "", err
		}
		var resp account.VerifySubscriptionResponse
		if err := json.Unmarshal([]byte(data), &resp); err != nil {
			return "", fmt.Errorf("error unmarshalling acknowledge apple purchase response: %v", err)
		}
		if resp.ActualUserID != 0 && resp.ActualUserToken != "" {
			/// This means the purchase was made on a different account and we need to switch to that account
			slog.Info("Purchase made on a different account, switching accounts", "actualUserId", resp.ActualUserID)
			if err := c.PatchSettings(settings.Settings{
				settings.UserIDKey: fmt.Sprintf("%d", resp.ActualUserID),
				settings.TokenKey:  resp.ActualUserToken,
			}); err != nil {
				return "", fmt.Errorf("error updating settings after account switch: %v", err)
			}
			userData, err := FetchUserData()
			if err != nil {
				return "", err
			}
			slog.Debug("fetched user data after account switch", "userdata", userData)
			return userData, nil
		}
		/// Purchase was made on the same account, just return "" to indicate success
		return "", nil

	})
}

func PaymentRedirect(provider, planId, email string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.PaymentRedirect(provider, planId, email) })

}

// /This is specifically for stripe subscriptions that require a redirect to complete the payment
// This is only used for macos
func StripeSubscriptionPaymentRedirect(subType, planId, email string) (string, error) {
	slog.Debug("stripeSubscriptionPaymentRedirect called")
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return c.StripeSubscriptionPaymentRedirect(subType, planId, email)
	})
}

/// User management apis

func Login(email, password string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.Login(email, password)
		slog.Debug("Login response", "response", string(b), "error", err)
		return string(b), err
	})
}

func StartChangeEmail(newEmail, password string) error {
	return withCore(func(c lanterncore.Core) error { return c.StartChangeEmail(newEmail, password) })
}

func CompleteChangeEmail(email, password, code string) error {
	return withCore(func(c lanterncore.Core) error { return c.CompleteChangeEmail(email, password, code) })
}

func SignUp(email, password string) error {
	return withCore(func(c lanterncore.Core) error { return c.SignUp(email, password) })
}

func Logout(email string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.Logout(email)
		return string(b), err
	})
}

func GetDataCapInfo() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.DataCapInfo() })
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func StartRecoveryByEmail(email string) error {
	return withCore(func(c lanterncore.Core) error { return c.StartRecoveryByEmail(email) })
}

// This will validate the recovery code sent to the user's email
func ValidateChangeEmailCode(email, code string) error {
	return withCore(func(c lanterncore.Core) error { return c.ValidateChangeEmailCode(email, code) })
}

func CompleteRecoveryByEmail(email, newPassword, code string) error {
	return withCore(func(c lanterncore.Core) error { return c.CompleteRecoveryByEmail(email, newPassword, code) })
}

func RemoveDevice(deviceId string) error {
	return withCore(func(c lanterncore.Core) error {
		linkresp, err := c.RemoveDevice(deviceId)
		if err != nil {
			return err
		}
		slog.Debug("Device removed successfully", "deviceId", deviceId, "response", linkresp)
		return nil
	})
}

func ReferralAttachment(referralCode string) error {
	return withCore(func(c lanterncore.Core) error {
		ok, err := c.ReferralAttachment(referralCode)
		if !ok {
			return err
		}
		return nil
	})
}

func DeleteAccount(email, password string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		b, err := c.DeleteAccount(email, password)
		return string(b), err
	})
}

func ActivationCode(email, resellerCode string) error {
	return withCore(func(c lanterncore.Core) error { return c.ActivationCode(email, resellerCode) })
}

func DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	return withCore(func(c lanterncore.Core) error { return c.DigitalOceanPrivateServer(events) })
}

func GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return withCore(func(c lanterncore.Core) error { return c.GoogleCloudPrivateServer(events) })
}

// ValidateSession validates the current private server session.
// this will re-trigger validation events and make sure user has added billing info etc.
func ValidateSession() error {
	return withCore(func(c lanterncore.Core) error { return c.ValidateSession() })
}

func SelectAccount(account string) error {
	return withCore(func(c lanterncore.Core) error { return c.SelectAccount(account) })
}

func SelectProject(project string) error {
	return withCore(func(c lanterncore.Core) error { return c.SelectProject(project) })
}

func StartDeployment(location, serverName string) error {
	return withCore(func(c lanterncore.Core) error { return c.StartDeployment(location, serverName) })
}

func CancelDeployment() error {
	return withCore(func(c lanterncore.Core) error { return c.CancelDeployment() })
}

func AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return withCore(func(c lanterncore.Core) error { return c.AddServerManagerInstance(ip, port, accessToken, tag, events) })
}

func InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return c.InviteToServerManagerInstance(ip, port, accessToken, inviteName)
	})
}

func RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error {
	return withCore(func(c lanterncore.Core) error { return c.RevokeServerManagerInvite(ip, port, accessToken, inviteName) })
}

func AddServerBasedOnURLs(urls string, skipCertVerification bool) (string, error) {
	slog.Debug("Adding server based on URLs", "urls", urls, "skipCertVerification", skipCertVerification)
	return withCoreR(func(c lanterncore.Core) (string, error) {
		tags, err := c.AddServersByURL(urls, skipCertVerification)
		if err != nil {
			return "", err
		}
		b, err := json.Marshal(tags)
		if err != nil {
			return "", fmt.Errorf("marshal tags: %w", err)
		}
		return string(b), nil
	})
}

func DeletePrivateServerByName(tag string) error {
	return withCore(func(c lanterncore.Core) error { return c.DeleteServer(tag) })
}

func UpdatePrivateServerName(oldTag, newTag string) error {
	return withCore(func(c lanterncore.Core) error {
		return c.UpdatePrivateServerName(oldTag, newTag)
	})
}

func GetSplitTunnelItems(filterType string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return c.GetSplitTunnelItemsFor(filterType)
	})
}

func GetSplitTunnelStateJSON() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		return c.GetSplitTunnelItems()
	})
}

// Developer-mode bindings.
//
// Maps and structs aren't supported as gomobile parameters/returns, so these
// mirror the FFI shape: callers exchange JSON strings. PatchSettings expects
// settings.Settings JSON; PatchEnvVars / GetEnvVars use map[string]string JSON.

func PatchSettings(patchJSON string) error {
	return withCore(func(c lanterncore.Core) error {
		var updates settings.Settings
		if err := json.Unmarshal([]byte(patchJSON), &updates); err != nil {
			return fmt.Errorf("invalid settings JSON: %w", err)
		}
		return c.PatchSettings(updates)
	})
}

func GetSettings() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		data, err := c.GetSettingsJSON()
		if err != nil {
			return "", err
		}
		return string(data), nil
	})
}

func PatchEnvVars(patchJSON string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		var updates map[string]string
		if err := json.Unmarshal([]byte(patchJSON), &updates); err != nil {
			return "", fmt.Errorf("invalid env JSON: %w", err)
		}
		result, err := c.PatchEnvVars(updates)
		if err != nil {
			return "", err
		}
		data, err := json.Marshal(result)
		if err != nil {
			return "", err
		}
		return string(data), nil
	})
}

func GetEnvVars() (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) {
		data, err := json.Marshal(c.GetEnvVars())
		if err != nil {
			return "", err
		}
		return string(data), nil
	})
}

func RunURLTests() error {
	return withCore(func(c lanterncore.Core) error {
		return c.RunOfflineURLTests()
	})
}

// SendConfigRequest triggers a config refresh on the daemon. Mirrors the FFI
// `updateConfig` export — kept under the SendConfig name so the mobile
// MethodChannel and Dart caller naming align.
func SendConfigRequest() error {
	return withCore(func(c lanterncore.Core) error {
		return c.UpdateConfig()
	})
}

// LogSubscription holds the cancellation handle for a TailLogs stream. Call
// Cancel to stop receiving log entries.
type LogSubscription struct {
	cancel context.CancelFunc
}

func (s *LogSubscription) Cancel() {
	if s == nil || s.cancel == nil {
		return
	}
	s.cancel()
	s.cancel = nil
}

// TailLogs streams log entries to the provided listener until the returned
// subscription is cancelled.
func TailLogs(listener utils.LogListener) (*LogSubscription, error) {
	if listener == nil {
		return nil, errors.New("log listener is required")
	}
	client, err := getClient()
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		if err := logs.Subscribe(ctx, client, listener.OnLogEntry); err != nil && ctx.Err() == nil {
			slog.Debug("log stream exited", "error", err)
		}
	}()
	return &LogSubscription{cancel: cancel}, nil
}
