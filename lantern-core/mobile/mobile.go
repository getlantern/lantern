package mobile

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sync/atomic"

	"github.com/getlantern/radiance/api"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"

	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
)

var (
	lanternCore        atomic.Value
	errLanternNotReady = errors.New("radiance not initialized")
)

func getCore() (lanterncore.Core, error) {
	v := lanternCore.Load()
	if v == nil {
		return nil, errLanternNotReady
	}
	return v.(lanterncore.Core), nil
}

// withCore is a helper function that provides access to the lanterncore.Core instance.
func withCore(fn func(c lanterncore.Core) error) error {
	c, err := getCore()
	if err != nil {
		return err
	}
	return fn(c)
}

// withCoreR is a helper function that provides type-safe access to the lanterncore.Core instance.
func withCoreR[T any](fn func(c lanterncore.Core) (T, error)) (T, error) {
	var zero T
	c, err := getCore()
	if err != nil {
		return zero, err
	}
	return fn(c)
}

// panicRecover is a helper function that recovers from panics and logs the error.
func panicRecover() {
	defer func() {
		if r := recover(); r != nil {
			slog.Error("Recovered from panic:", "error", r)
		}
	}()
}

func SetupRadiance(opts *utils.Opts, eventEmitter utils.FlutterEventEmitter) error {
	slog.Info("Setting up Radiance", "opts", opts)

	// Initialize lantern core
	c, err := lanterncore.New(opts, eventEmitter)
	if err != nil {
		return fmt.Errorf("unable to create LanternCore: %v", err)
	}
	lanternCore.Store(c)
	return nil
}

func AvailableFeatures() []byte {
	b, err := withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.AvailableFeatures(), nil })
	if err != nil {
		return []byte(`{}`)
	}
	return b
}

func MyDeviceId() (string, error) {
	id, err := withCoreR(func(c lanterncore.Core) (string, error) { return c.MyDeviceId(), nil })
	if err != nil {
		return "", err
	}
	return id, nil
}

func IsRadianceConnected() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) { return c.IsRadianceConnected(), nil })
	if err != nil {
		return false
	}
	return ok
}

func StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	slog.Info("Starting VPN")
	return vpn_tunnel.StartVPN(platform, opts)
}

func StopVPN() error {
	return vpn_tunnel.StopVPN()
}

// // GetAvailableServers returns the available servers in JSON format.
// // This function retrieves the servers from lantern
func GetAvailableServers() ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.GetAvailableServers(), nil })
}

// ConnectToServer connects to a server using the provided location type and tag.
// It works with private servers and lantern location servers.
func ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	return vpn_tunnel.ConnectToServer(locationType, tag, platIfce, options)
}

func IsVPNConnected() bool {
	return vpn_tunnel.IsVPNRunning()
}

func GetSelectedServer() string {
	return vpn_tunnel.GetSelectedServer()
}

func GetAutoLocation() (string, error) {
	location, err := vpn_tunnel.GetAutoLocation()
	if err != nil {
		return "", err
	}
	return withCoreR(func(c lanterncore.Core) (string, error) {
		servers, ok := c.GetServerByTag(location.Lantern)
		if !ok {
			return "", fmt.Errorf("no server found with tag: %s", location.Lantern)
		}
		jsonBytes, err := json.Marshal(servers)
		if err != nil {
			return "", fmt.Errorf("error marshalling server: %v", err)
		}
		slog.Debug("Auto location server:", "server", string(jsonBytes))
		return string(jsonBytes), nil
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
	return withCore(func(c lanterncore.Core) error { c.SetSplitTunnelingEnabled(enabled); return nil })
}

func IsSplitTunnelingEnabled() bool {
	ok, err := withCoreR(func(c lanterncore.Core) (bool, error) { return c.IsSplitTunnelingEnabled(), nil })
	if err != nil {
		return false
	}
	return ok
}

func ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	return withCore(func(c lanterncore.Core) error {
		return c.ReportIssue(email, issueType, description, device, model, logFilePath)
	})
}

func LoadInstalledApps(dataDir string) (string, error) {
	return lanterncore.LoadInstalledApps(dataDir)
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() (*api.UserDataResponse, error) {
	return withCoreR(func(c lanterncore.Core) (*api.UserDataResponse, error) { return c.CreateUser() })
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	slog.Debug("User data")
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.UserData() })
}

// GetUserData will get the user data from the server
func FetchUserData() ([]byte, error) {
	slog.Debug("Fetching user data")
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.FetchUserData() })
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	return withCoreR(func(c lanterncore.Core) (string, error) { return c.OAuthLoginUrl(provider) })
}

func OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.OAuthLoginCallback(oAuthToken) })
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

func AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	return withCore(func(c lanterncore.Core) error { return c.AcknowledgeGooglePurchase(purchaseToken, planId) })
}

func AcknowledgeApplePurchase(receipt, planII string) error {
	return withCore(func(c lanterncore.Core) error { return c.AcknowledgeApplePurchase(receipt, planII) })
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

func Login(email, password string) ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.Login(email, password) })
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

func Logout(email string) ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.Logout(email) })
}

func GetDataCapInfo() ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.DataCapInfo() })
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

// // This will complete the email recovery by setting the new password
// func CompleteChangeEmail(email, password, code string) error {
// 	return c.CompleteChangeEmail(email, password, code)
// }

func DeleteAccount(email, password string) ([]byte, error) {
	return withCoreR(func(c lanterncore.Core) ([]byte, error) { return c.DeleteAccount(email, password) })
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

func SelectedCertFingerprint(fp string) {
	withCore(func(c lanterncore.Core) error {
		c.SelectedCertFingerprint(fp)
		return nil
	})
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
