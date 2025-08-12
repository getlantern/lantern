package mobile

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"runtime"
	"strconv"
	"sync/atomic"

	"github.com/getlantern/golog"
	privateserver "github.com/getlantern/lantern-outline/lantern-core/private-server"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/servers"
	"github.com/getlantern/radiance/vpn"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
	"google.golang.org/protobuf/proto"
)

var log = golog.LoggerFor("lantern-outline.mobile")

var (
	serverManager      atomic.Pointer[servers.Manager]
	splitTunnelHandler atomic.Pointer[vpn.SplitTunnel]
	apiClient          atomic.Pointer[api.APIClient]
	userInfo           atomic.Pointer[common.UserInfo]
	rad                atomic.Pointer[radiance.Radiance]
)

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}

func SetupRadiance(opts *utils.Opts) error {
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Recovered from panic in SetupRadiance: %v", r)
		}
	}()

	r, err := radiance.NewRadiance(radiance.Options{
		LogDir:   opts.LogDir,
		DataDir:  opts.DataDir,
		DeviceID: opts.Deviceid,
		LogLevel: opts.LogLevel,
		Locale:   opts.Locale,
	})
	log.Debugf("Paths: %s %s", common.LogPath(), common.DataPath())
	if err != nil {
		return fmt.Errorf("unable to create Radiance: %v", err)
	}
	rad.Store(r)

	sth, sthErr := vpn.NewSplitTunnelHandler()
	if sthErr != nil {
		return fmt.Errorf("unable to create split tunnel handler: %v", sthErr)
	}
	splitTunnelHandler.Store(sth)
	sm, mngErr := servers.NewManager(opts.DataDir)
	if mngErr != nil {
		return fmt.Errorf("unable to create server manager: %v", mngErr)
	}
	serverManager.Store(sm)

	info := r.UserInfo()
	userInfo.Store(&info)
	apiClient.Store(r.APIHandler())

	log.Debug("Radiance setup successfully")
	go func() {
		if info.LegacyID() == 0 {
			log.Debug("Creating user")
			if _, err := CreateUser(); err != nil {
				log.Errorf("Error creating user: %v", err)
			}
		}
		if _, err := FetchUserData(); err != nil {
			log.Errorf("Error fetching user data: %v", err)
		}
	}()

	return nil
}

func AvailableFeatures() []byte {
	if rad.Load() == nil {
		log.Error("Radiance server not initialized")
		return nil
	}
	features := rad.Load().Features()
	log.Debugf("Available features: %v", features)
	jsonBytes, err := json.Marshal(features)
	if err != nil {
		log.Errorf("Error marshalling features: %v", err)
		return nil
	}
	return jsonBytes
}

func IsRadianceConnected() bool {
	return rad.Load() != nil
}

func StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	log.Debug("Starting VPN")
	err := vpn_tunnel.StartVPN(platform, opts)
	if err != nil {
		log.Errorf("Error starting VPN: %v", err)
		return err
	}
	return nil
}

func StopVPN() error {
	log.Debug("Stopping VPN")
	er := vpn_tunnel.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

// ConnectToServer connects to a server using the provided location type and tag.
// It works with private servers and lantern location servers.
func ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	log.Debugf("Setting private server with tag: %s", tag)
	err := vpn_tunnel.ConnectToServer(locationType, tag, platIfce, options)
	if err != nil {
		return log.Errorf("Error setting private server: %v", err)
	}
	log.Debugf("Private server set with tag: %s", tag)
	return nil
}

func IsVPNConnected() bool {
	return vpn_tunnel.IsVPNRunning()
}

func AddSplitTunnelItem(filterType, item string) error {
	if splitTunnelHandler.Load() == nil {
		return errors.New("splitTunnelHandler is nil")
	}
	if err := splitTunnelHandler.Load().AddItem(filterType, item); err != nil {
		return fmt.Errorf("error adding item: %v", err)
	}
	log.Debugf("added %s split tunneling item %s", filterType, item)
	return nil
}

func RemoveSplitTunnelItem(filterType, item string) error {
	if splitTunnelHandler.Load() == nil {
		return errors.New("splitTunnelHandler is nil")
	}
	if err := splitTunnelHandler.Load().RemoveItem(filterType, item); err != nil {
		return fmt.Errorf("error removing item: %v", err)
	}
	log.Debugf("removed %s split tunneling item %s", filterType, item)
	return nil
}

func ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	if rad.Load() == nil {
		return fmt.Errorf("radiance not setup")
	}

	report := radiance.IssueReport{
		Type:        issueType,
		Description: description,
		// Try to read the log file as an attachment
		Attachments: utils.CreateLogAttachment(logFilePath),
		Device:      device,
		Model:       model,
	}

	if err := rad.Load().ReportIssue(email, report); err != nil {
		return fmt.Errorf("error reporting issue: %w", err)
	}

	log.Debugf("Reported issue: %s – %s on %s/%s", email, issueType, device, model)
	return nil
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() (*api.UserDataResponse, error) {
	if apiClient.Load() == nil {
		return nil, fmt.Errorf("apiClient not initialized")
	}
	log.Debug("Creating user")
	user, err := apiClient.Load().NewUser(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	return user, nil
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	if userInfo.Load() == nil {
		return nil, fmt.Errorf("userInfo not initialized")
	}
	log.Debug("Getting user data from user config")
	user, err := (*userInfo.Load()).GetData()
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	fmt.Printf("UserData: %v\n", user)
	bytes, err := proto.Marshal(user)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

// GetUserData will get the user data from the server
func FetchUserData() ([]byte, error) {
	log.Debug("Getting user data")
	if apiClient.Load() == nil {
		return nil, fmt.Errorf("api client not initialized")
	}
	// this call will also save the user data in the user config
	// so we can use it later
	user, err := apiClient.Load().UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	log.Debug("Getting OAuth login URL")
	if apiClient.Load() == nil {
		return "", fmt.Errorf("api client not initialized")
	}
	oauthLoginURL, err := apiClient.Load().OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", log.Errorf("Error getting OAuth login URL: %v", err)
	}
	log.Debugf("OAuthLoginUrl response: %v", oauthLoginURL)
	return oauthLoginURL, nil
}

func OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	log.Debug("Getting OAuth login callback")
	jwtUserInfo, err := utils.DecodeJWT(oAuthToken)
	if err != nil {
		return nil, log.Errorf("Error decoding JWT: %v", err)
	}
	if apiClient.Load() == nil || userInfo.Load() == nil {
		return nil, fmt.Errorf("api client or user info not initialized")
	}
	// Temporary  set user data to so api can read it
	login := &protos.LoginResponse{
		LegacyID:    jwtUserInfo.LegacyUserId,
		LegacyToken: jwtUserInfo.LegacyToken,
	}
	(*userInfo.Load()).SetData(login)
	///Get user data from api this will also save data in user config
	user, err := apiClient.Load().UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	userResponse := &protos.LoginResponse{
		Id:             jwtUserInfo.Email,
		EmailConfirmed: true,
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	(*userInfo.Load()).SetData(userResponse)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

func StripeSubscription(email, planID string) (string, error) {
	log.Debug("Creating stripe subscription")
	if apiClient.Load() == nil {
		return "", fmt.Errorf("api client not initialized")
	}
	stripeSubscription, err := apiClient.Load().NewStripeSubscription(context.Background(), email, planID)
	if err != nil {
		return "", log.Errorf("Error creating stripe subscription: %v", err)
	}
	log.Debugf("StripeSubscription response: %v", stripeSubscription)
	jsonData, err := json.Marshal(stripeSubscription)
	if err != nil {
		return "", log.Errorf("Error marshalling stripe subscription: %v", err)
	}
	// Convert bytes to string and print
	jsonString := string(jsonData)
	log.Debugf("StripeSubscription response: %v", jsonString)
	return jsonString, nil
}

func Plans(channel string) (string, error) {
	log.Debug("Getting plans")
	if apiClient.Load() == nil {
		return "", fmt.Errorf("api client not initialized")
	}
	plans, err := apiClient.Load().SubscriptionPlans(context.Background(), channel)
	if err != nil {
		return "", log.Errorf("Error getting plans: %v", err)
	}
	jsonData, err := json.Marshal(plans)
	if err != nil {
		return "", log.Errorf("Error marshalling plans: %v", err)
	}
	log.Debugf("Plans response: %v", string(jsonData))
	// Convert bytes to string and print
	return string(jsonData), nil
}
func StripeBillingPortalUrl() (string, error) {
	log.Debug("Getting stripe billing portal")
	if apiClient.Load() == nil {
		return "", fmt.Errorf("api client not initialized")
	}
	billingPortal, err := apiClient.Load().StripeBillingPortalUrl()
	if err != nil {
		return "", log.Errorf("Error getting stripe billing portal: %v", err)
	}
	log.Debugf("StripeBillingPortal response: %v", billingPortal)
	return billingPortal, nil
}

func AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	log.Debugf("Purchase token: %s planId %s", purchaseToken, planId)
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	status, _, err := apiClient.Load().VerifySubscription(context.Background(), api.GoogleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge google purchase: %v", status)
	return nil
}

func AcknowledgeApplePurchase(receipt, planII string) error {
	log.Debugf("Apple receipt: %s planId %s", receipt, planII)
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	params := map[string]string{
		"receipt": receipt,
		"planId":  planII,
	}
	status, _, err := apiClient.Load().VerifySubscription(context.Background(), api.AppleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge apple purchase: %v", status)
	return nil
}

func PaymentRedirect(provider, planId, email string) (string, error) {
	log.Debug("Payment redirect")
	if apiClient.Load() == nil || userInfo.Load() == nil {
		return "", fmt.Errorf("api client or user info not initialized")
	}
	deviceName := (*userInfo.Load()).DeviceID()
	body := api.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	paymentRedirect, err := apiClient.Load().PaymentRedirect(context.Background(), body)
	if err != nil {
		return "", log.Errorf("Error getting payment redirect: %v", err)
	}
	log.Debugf("Payment redirect response: %v", paymentRedirect)
	return paymentRedirect, nil
}

/// User management apis

func Login(email, password string) ([]byte, error) {
	log.Debug("Logging in user")
	if apiClient.Load() == nil || userInfo.Load() == nil {
		return nil, fmt.Errorf("api client or user info not initialized")
	}
	deviceID := (*userInfo.Load()).DeviceID()
	loginResponse, err := apiClient.Load().Login(context.Background(), email, password, deviceID)
	if err != nil {
		return nil, log.Errorf("%v", err)
	}
	log.Debugf("Login response: %v", loginResponse)
	protoUserData, err := proto.Marshal(loginResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

func SignUp(email, password string) error {
	log.Debug("Signing up user")
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().SignUp(context.Background(), email, password)
	if err != nil {
		return log.Errorf("Error signing up: %v", err)
	}
	return nil
}

func Logout(email string) ([]byte, error) {
	log.Debug("Logging out")
	if apiClient.Load() == nil {
		return nil, fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().Logout(context.Background(), email)
	if err != nil {
		return nil, log.Errorf("Error logging out: %v", err)
	}
	// this call will save data
	user, err := CreateUser()
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return protoUserData, nil
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func StartRecoveryByEmail(email string) error {
	log.Debug("Starting change email")
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().StartRecoveryByEmail(context.Background(), email)
	if err != nil {
		return log.Errorf("Error starting change email: %v", err)
	}
	return nil
}

// This will validate the recovery code sent to the user's email
func ValidateChangeEmailCode(email, code string) error {
	log.Debug("Validating change email code")
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().ValidateEmailRecoveryCode(context.Background(), email, code)
	if err != nil {
		return log.Errorf("Error validating change email code: %v", err)
	}
	log.Debugf("ValidateChangeEmailCode successful for email: %s", email)
	return nil
}

// This will complete the email recovery by setting the new password
func CompleteChangeEmail(email, password, code string) error {
	log.Debug("Completing change email")
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().CompleteRecoveryByEmail(context.Background(), email, password, code)
	if err != nil {
		return log.Errorf("Error completing change email: %v", err)
	}
	return nil
}

func DeleteAccount(email, password string) ([]byte, error) {
	log.Debug("Deleting account")
	if apiClient.Load() == nil {
		return nil, fmt.Errorf("api client not initialized")
	}
	err := apiClient.Load().DeleteAccount(context.Background(), email, password)
	if err != nil {
		return nil, log.Errorf("Error deleting account: %v", err)
	}
	user, err := CreateUser()
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}

	(*userInfo.Load()).SetData(login)
	return protoUserData, nil
}

func ActivationCode(email, resellerCode string) error {
	log.Debug("Getting activation code")
	if apiClient.Load() == nil {
		return fmt.Errorf("api client not initialized")
	}
	purchase, err := apiClient.Load().ActivationCode(context.Background(), email, resellerCode)
	if err != nil {
		return log.Errorf("Error getting activation code: %v", err)
	}
	log.Debugf("ActivationCode response: %v", purchase)
	if purchase.Status != "ok" {
		return fmt.Errorf("activation code failed: %s", purchase.Status)
	}
	return nil
}

//Private methods

func DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	if serverManager.Load() == nil {
		return log.Errorf("Server manager not initialized")
	}
	log.Debug("Starting DigitalOcean private server flow")
	return privateserver.StartDigitalOceanPrivateServerFlow(events, serverManager.Load())
}

func GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	if serverManager.Load() == nil {
		return log.Errorf("Server manager not initialized")
	}
	return privateserver.StartGoogleCloudPrivateServerFlow(events, serverManager.Load())
}

func SelectAccount(account string) error {
	return privateserver.SelectAccount(account)
}

func SelectProject(project string) error {
	return privateserver.SelectProject(project)
}

func StartDepolyment(location, serverName string) error {
	return privateserver.StartDepolyment(location, serverName)
}

func CancelDepolyment() error {
	return privateserver.CancelDepolyment()
}

func SelectedCertFingerprint(fp string) {
	privateserver.SelectedCertFingerprint(fp)
}

func AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	if serverManager.Load() == nil {
		return log.Errorf("Server manager not initialized")
	}
	return privateserver.AddServerManually(ip, port, accessToken, tag, serverManager.Load(), events)
}
func InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error) {
	if serverManager.Load() == nil {
		return "", log.Errorf("Server manager not initialized")
	}
	portInt, _ := strconv.Atoi(port)
	accessToken, err := privateserver.InviteToServerManagerInstance(ip, portInt, accessToken, inviteName, serverManager.Load())
	if err != nil {
		return "", log.Errorf("Error inviting to server manager instance: %v", err)
	}
	log.Debugf("Invite to server manager instance %s:%d with name %s", ip, portInt, inviteName)
	return accessToken, nil
}

func RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error {
	if serverManager.Load() == nil {
		return log.Errorf("Server manager not initialized")
	}
	portInt, _ := strconv.Atoi(port)
	log.Debugf("Revoking invite %s for server %s:%d", inviteName, ip, port)
	return privateserver.RevokeServerManagerInvite(ip, portInt, accessToken, inviteName, serverManager.Load())
}
