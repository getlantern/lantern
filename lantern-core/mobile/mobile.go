package mobile

import (
	"fmt"
	"log/slog"
	"runtime"
	"sync/atomic"

	lanterncore "github.com/getlantern/lantern-outline/lantern-core"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/radiance/api"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var lanternCore atomic.Pointer[lanterncore.Core]

func init() {
	stub := lanterncore.Stub()
	lanternCore.Store(&stub)
}

func core() lanterncore.Core {
	c := lanternCore.Load()
	return *c
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}

func SetupRadiance(opts *utils.Opts) error {
	defer func() {
		if r := recover(); r != nil {
			slog.Error("Recovered from panic in SetupRadiance:", "error", r)
		}
	}()

	c, err := lanterncore.New(opts)
	if err != nil {
		return fmt.Errorf("unable to create LanternCore: %v", err)
	}
	lanternCore.Store(&c)
	return nil
}

func AvailableFeatures() []byte {
	return core().AvailableFeatures()
}

func IsRadianceConnected() bool {
	//return core.Load().IsRadianceConnected()
	return true
}

func StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	return core().StartVPN(platform, opts)
}

func StopVPN() error {
	return core().StopVPN()
}

// ConnectToServer connects to a server using the provided location type and tag.
// It works with private servers and lantern location servers.
func ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	return core().ConnectToServer(locationType, tag, platIfce, options)
}

func IsVPNConnected() bool {
	return core().IsVPNConnected()
}

func AddSplitTunnelItem(filterType, item string) error {
	return core().AddSplitTunnelItem(filterType, item)
}

func RemoveSplitTunnelItem(filterType, item string) error {
	return core().RemoveSplitTunnelItem(filterType, item)
}

func ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	return core().ReportIssue(email, issueType, description, device, model, logFilePath)
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() (*api.UserDataResponse, error) {
	return core().CreateUser()
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	return core().UserData()
}

// GetUserData will get the user data from the server
func FetchUserData() ([]byte, error) {
	return core().FetchUserData()
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	return core().OAuthLoginUrl(provider)
}

func OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	return core().OAuthLoginCallback(oAuthToken)
}

func StripeSubscription(email, planID string) (string, error) {
	return core().StripeSubscription(email, planID)
}

func Plans(channel string) (string, error) {
	return core().Plans(channel)
}
func StripeBillingPortalUrl() (string, error) {
	return core().StripeBillingPortalUrl()
}

func AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	return core().AcknowledgeGooglePurchase(purchaseToken, planId)
}

func AcknowledgeApplePurchase(receipt, planII string) error {
	return core().AcknowledgeApplePurchase(receipt, planII)
}

func PaymentRedirect(provider, planId, email string) (string, error) {
	return core().PaymentRedirect(provider, planId, email)
}

/// User management apis

func Login(email, password string) ([]byte, error) {
	return core().Login(email, password)
}

func SignUp(email, password string) error {
	return core().SignUp(email, password)
}

func Logout(email string) ([]byte, error) {
	return core().Logout(email)
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func StartRecoveryByEmail(email string) error {
	return core().StartRecoveryByEmail(email)
}

// This will validate the recovery code sent to the user's email
func ValidateChangeEmailCode(email, code string) error {
	return core().ValidateChangeEmailCode(email, code)
}

// This will complete the email recovery by setting the new password
func CompleteChangeEmail(email, password, code string) error {
	return core().CompleteChangeEmail(email, password, code)
}

func DeleteAccount(email, password string) ([]byte, error) {
	return core().DeleteAccount(email, password)
}

func ActivationCode(email, resellerCode string) error {
	return core().ActivationCode(email, resellerCode)
}

func DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	return core().DigitalOceanPrivateServer(events)
}

func GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return core().GoogleCloudPrivateServer(events)
}

func SelectAccount(account string) error {
	return core().SelectAccount(account)
}

func SelectProject(project string) error {
	return core().SelectProject(project)
}

func StartDepolyment(location, serverName string) error {
	return core().StartDeployment(location, serverName)
}

func CancelDepolyment() error {
	return core().CancelDeployment()
}

func SelectedCertFingerprint(fp string) {
	core().SelectedCertFingerprint(fp)
}

func AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return core().AddServerManagerInstance(ip, port, accessToken, tag, events)
}

func InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error) {
	return core().InviteToServerManagerInstance(ip, port, accessToken, inviteName)
}

func RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error {
	return core().RevokeServerManagerInvite(ip, port, accessToken, inviteName)
}
