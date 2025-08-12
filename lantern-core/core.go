package lanterncore

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strconv"

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
	"google.golang.org/protobuf/proto"
)

// LanternCore is the main structure accessing the Lantern backend.
type LanternCore struct {
	opts          *utils.Opts
	rad           *radiance.Radiance
	splitTunnel   *vpn.SplitTunnel
	serverManager *servers.Manager
	userInfo      common.UserInfo
	apiClient     *api.APIClient
}

type App interface {
	AvailableFeatures() []byte
	ReportIssue(email, issueType, description, device, model, logFilePath string) error
}

type User interface {
	CreateUser() (*api.UserDataResponse, error)
	UserData() ([]byte, error)
	FetchUserData() ([]byte, error)
	OAuthLoginUrl(provider string) (string, error)
	OAuthLoginCallback(oAuthToken string) ([]byte, error)

	Login(email, password string) ([]byte, error)
	SignUp(email, password string) error
	Logout(email string) ([]byte, error)
	StartRecoveryByEmail(email string) error
	ValidateChangeEmailCode(email, code string) error
	CompleteChangeEmail(email, password, code string) error
	DeleteAccount(email, password string) ([]byte, error)
}

type PrivateServer interface {
	DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error
	GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error
	SelectAccount(account string) error
	SelectProject(project string) error
	CancelDeployment() error
	AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error
	InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error)
	RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error
	SelectedCertFingerprint(fp string)
	StartDeployment(location, serverName string) error
}

type Payment interface {
	StripeSubscription(email, planID string) (string, error)
	Plans(channel string) (string, error)
	StripeBillingPortalUrl() (string, error)
	AcknowledgeGooglePurchase(purchaseToken, planId string) error
	AcknowledgeApplePurchase(receipt, planII string) error
	PaymentRedirect(provider, planId, email string) (string, error)
	ActivationCode(email, resellerCode string) error
	SubscriptionPaymentRedirectURL(redirectBody api.PaymentRedirectData) (string, error)
	StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error)
}

type VPN interface {
	StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error
	StopVPN() error
	ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error
	IsVPNConnected() bool
	AddSplitTunnelItem(filterType, item string) error
	RemoveSplitTunnelItem(filterType, item string) error
}

type Core interface {
	App
	User
	VPN
	Payment
	PrivateServer
}

// Make sure LanternCore implements the Core interface
var _ Core = (*LanternCore)(nil)

func New(opts *utils.Opts) (Core, error) {
	if opts == nil {
		return nil, fmt.Errorf("opts cannot be nil")
	}

	slog.Debug("Initializing LanternCore with opts: ", "opts", opts)

	core := &LanternCore{
		opts: opts,
	}

	if err := core.initialize(); err != nil {
		return nil, fmt.Errorf("failed to initialize LanternCore: %w", err)
	}

	return core, nil
}

func (lc *LanternCore) initialize() error {
	slog.Debug("Starting LanternCore initialization")

	var radErr error
	if lc.rad, radErr = radiance.NewRadiance(radiance.Options{
		LogDir:   lc.opts.LogDir,
		DataDir:  lc.opts.DataDir,
		DeviceID: lc.opts.Deviceid,
		LogLevel: lc.opts.LogLevel,
		Locale:   lc.opts.Locale,
	}); radErr != nil {
		return fmt.Errorf("failed to create Radiance: %w", radErr)
	}
	slog.Debug("Paths:", "logs", common.LogPath(), "data", common.DataPath())

	var sthErr error
	if lc.splitTunnel, sthErr = vpn.NewSplitTunnelHandler(); sthErr != nil {
		return fmt.Errorf("unable to create split tunnel handler: %v", sthErr)
	}

	var smErr error
	if lc.serverManager, smErr = servers.NewManager(lc.opts.DataDir); smErr != nil {
		return fmt.Errorf("unable to create server manager: %v", smErr)
	}

	lc.userInfo = lc.rad.UserInfo()
	lc.apiClient = lc.rad.APIHandler()

	slog.Debug("LanternCore initialized successfully")
	return nil
}

func (lc *LanternCore) AvailableFeatures() []byte {
	features := lc.rad.Features()
	slog.Debug("Available features", "features", features)
	jsonBytes, err := json.Marshal(features)
	if err != nil {
		slog.Error("Error marshalling features", "error", err)
		return nil
	}
	return jsonBytes
}

func (lc *LanternCore) StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	slog.Debug("Starting VPN")
	return vpn_tunnel.StartVPN(platform, opts)
}

func (lc *LanternCore) StopVPN() error {
	slog.Debug("Stopping VPN")
	return vpn_tunnel.StopVPN()
}

// ConnectToServer connects to a server using the provided location type and tag.
// It works with private servers and lantern location servers.
func (lc *LanternCore) ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	slog.Debug("Setting private server with tag: ", "tag", tag)
	return vpn_tunnel.ConnectToServer(locationType, tag, platIfce, options)
}

func (lc *LanternCore) IsVPNConnected() bool {
	return vpn_tunnel.IsVPNRunning()
}

func (lc *LanternCore) AddSplitTunnelItem(filterType, item string) error {
	return lc.splitTunnel.AddItem(filterType, item)
}

func (lc *LanternCore) RemoveSplitTunnelItem(filterType, item string) error {
	return lc.splitTunnel.RemoveItem(filterType, item)
}

func (lc *LanternCore) ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	report := radiance.IssueReport{
		Type:        issueType,
		Description: description,
		// Try to read the log file as an attachment
		Attachments: utils.CreateLogAttachment(logFilePath),
		Device:      device,
		Model:       model,
	}

	if err := lc.rad.ReportIssue(email, report); err != nil {
		return fmt.Errorf("error reporting issue: %w", err)
	}

	slog.Debug("Reported issue: %s – %s on %s/%s", email, issueType, device, model)
	return nil
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func (lc *LanternCore) CreateUser() (*api.UserDataResponse, error) {
	slog.Debug("Creating user")
	return lc.apiClient.NewUser(context.Background())
}

// this will return the user data from the user config
func (lc *LanternCore) UserData() ([]byte, error) {
	slog.Debug("Getting user data from user config")
	user, err := lc.userInfo.GetData()
	if err != nil {
		return nil, fmt.Errorf("error getting user data: %w", err)
	}
	fmt.Printf("UserData: %v\n", user)
	bytes, err := proto.Marshal(user)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}
	return bytes, nil
}

// GetUserData will get the user data from the server
func (lc *LanternCore) FetchUserData() ([]byte, error) {
	slog.Debug("Getting user data")
	// this call will also save the user data in the user config
	// so we can use it later
	user, err := lc.apiClient.UserData(context.Background())
	if err != nil {
		return nil, fmt.Errorf("error getting user data: %w", err)
	}
	slog.Debug("UserData response:", "user", user)
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}
	return protoUserData, nil
}

// OAuth Methods
func (lc *LanternCore) OAuthLoginUrl(provider string) (string, error) {
	slog.Debug("Getting OAuth login URL")
	oauthLoginURL, err := lc.apiClient.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", fmt.Errorf("error getting OAuth login URL: %w", err)
	}
	slog.Debug("OAuthLoginUrl response: %v", oauthLoginURL)
	return oauthLoginURL, nil
}

func (lc *LanternCore) OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	slog.Debug("Getting OAuth login callback")
	jwtUserInfo, err := utils.DecodeJWT(oAuthToken)
	if err != nil {
		return nil, fmt.Errorf("error decoding JWT: %w", err)
	}
	// Temporary  set user data to so api can read it
	login := &protos.LoginResponse{
		LegacyID:    jwtUserInfo.LegacyUserId,
		LegacyToken: jwtUserInfo.LegacyToken,
	}
	lc.userInfo.SetData(login)
	///Get user data from api this will also save data in user config
	user, err := lc.apiClient.UserData(context.Background())
	if err != nil {
		return nil, fmt.Errorf("error getting user data: %w", err)
	}
	slog.Debug("UserData response:", "user", user)
	userResponse := &protos.LoginResponse{
		Id:             jwtUserInfo.Email,
		EmailConfirmed: true,
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	lc.userInfo.SetData(userResponse)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}
	return bytes, nil
}

func (lc *LanternCore) StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error) {
	redirectBody := api.PaymentRedirectData{
		Provider:    "stripe",
		Plan:        planID,
		DeviceName:  lc.userInfo.DeviceID(),
		Email:       email,
		BillingType: api.SubscriptionType(subscriptionType),
	}
	return lc.SubscriptionPaymentRedirectURL(redirectBody)
}

func (lc *LanternCore) StripeSubscription(email, planID string) (string, error) {
	slog.Debug("Creating stripe subscription")
	stripeSubscription, err := lc.apiClient.NewStripeSubscription(context.Background(), email, planID)
	if err != nil {
		return "", fmt.Errorf("error creating stripe subscription: %w", err)
	}
	slog.Debug("StripeSubscription response:", "response", stripeSubscription)
	jsonData, err := json.Marshal(stripeSubscription)
	if err != nil {
		return "", fmt.Errorf("error marshalling stripe subscription: %w", err)
	}
	// Convert bytes to string and print
	jsonString := string(jsonData)
	slog.Debug("StripeSubscription response:", "response", jsonString)
	return jsonString, nil
}

func (lc *LanternCore) Plans(channel string) (string, error) {
	slog.Debug("Getting plans")
	plans, err := lc.apiClient.SubscriptionPlans(context.Background(), channel)
	if err != nil {
		return "", fmt.Errorf("error getting plans: %w", err)
	}
	jsonData, err := json.Marshal(plans)
	if err != nil {
		return "", fmt.Errorf("error marshalling plans: %w", err)
	}
	slog.Debug("Plans response:", "response", string(jsonData))
	// Convert bytes to string and print
	return string(jsonData), nil
}
func (lc *LanternCore) StripeBillingPortalUrl() (string, error) {
	slog.Debug("Getting stripe billing portal")
	billingPortal, err := lc.apiClient.StripeBillingPortalUrl()
	if err != nil {
		return "", fmt.Errorf("error getting stripe billing portal: %w", err)
	}
	slog.Debug("StripeBillingPortal response: ", "portal", billingPortal)
	return billingPortal, nil
}

func (lc *LanternCore) AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	slog.Debug("Purchase token: ", "token", purchaseToken, "planId", planId)
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	status, _, err := lc.apiClient.VerifySubscription(context.Background(), api.GoogleService, params)
	if err != nil {
		return fmt.Errorf("error acknowledging google purchase: %w", err)
	}
	slog.Debug("acknowledge google purchase:", "status", status)
	return nil
}

func (lc *LanternCore) AcknowledgeApplePurchase(receipt, planII string) error {
	slog.Debug("Apple receipt:", "receipt", receipt, "planId", planII)
	params := map[string]string{
		"receipt": receipt,
		"planId":  planII,
	}
	status, _, err := lc.apiClient.VerifySubscription(context.Background(), api.AppleService, params)
	if err != nil {
		return fmt.Errorf("error acknowledging apple purchase: %w", err)
	}
	slog.Debug("acknowledge apple purchase: ", "status", status)
	return nil
}

func (lc *LanternCore) SubscriptionPaymentRedirectURL(redirectBody api.PaymentRedirectData) (string, error) {
	slog.Debug("Getting payment redirect URL")
	return lc.apiClient.SubscriptionPaymentRedirectURL(context.Background(), redirectBody)
}

func (lc *LanternCore) PaymentRedirect(provider, planId, email string) (string, error) {
	slog.Debug("Payment redirect")
	deviceName := lc.userInfo.DeviceID()
	body := api.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	paymentRedirect, err := lc.apiClient.PaymentRedirect(context.Background(), body)
	if err != nil {
		return "", fmt.Errorf("error getting payment redirect: %w", err)
	}
	slog.Debug("Payment redirect response: ", "response", paymentRedirect)
	return paymentRedirect, nil
}

/// User management apis

func (lc *LanternCore) Login(email, password string) ([]byte, error) {
	slog.Debug("Logging in user")
	deviceID := lc.userInfo.DeviceID()
	loginResponse, err := lc.apiClient.Login(context.Background(), email, password, deviceID)
	if err != nil {
		return nil, fmt.Errorf("error logging in: %w", err)
	}
	slog.Debug("Login response: ", "response", loginResponse)
	protoUserData, err := proto.Marshal(loginResponse)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}
	return protoUserData, nil
}

func (lc *LanternCore) SignUp(email, password string) error {
	slog.Debug("Signing up user")
	return lc.apiClient.SignUp(context.Background(), email, password)
}

func (lc *LanternCore) Logout(email string) ([]byte, error) {
	slog.Debug("Logging out")
	err := lc.apiClient.Logout(context.Background(), email)
	if err != nil {
		return nil, fmt.Errorf("error logging out: %w", err)
	}
	// this call will save data
	user, err := lc.CreateUser()
	if err != nil {
		return nil, fmt.Errorf("error creating user: %w", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}
	return protoUserData, nil
}

// Email Recovery Methods
// This will start the email recovery process by sending a recovery code to the user's email
func (lc *LanternCore) StartRecoveryByEmail(email string) error {
	slog.Debug("Starting change email")
	return lc.apiClient.StartRecoveryByEmail(context.Background(), email)
}

// This will validate the recovery code sent to the user's email
func (lc *LanternCore) ValidateChangeEmailCode(email, code string) error {
	slog.Debug("Validating change email code")
	return lc.apiClient.ValidateEmailRecoveryCode(context.Background(), email, code)
}

// This will complete the email recovery by setting the new password
func (lc *LanternCore) CompleteChangeEmail(email, password, code string) error {
	slog.Debug("Completing change email")
	return lc.apiClient.CompleteRecoveryByEmail(context.Background(), email, password, code)
}

func (lc *LanternCore) DeleteAccount(email, password string) ([]byte, error) {
	slog.Debug("Deleting account")
	err := lc.apiClient.DeleteAccount(context.Background(), email, password)
	if err != nil {
		return nil, fmt.Errorf("error deleting account: %w", err)
	}
	user, err := lc.CreateUser()
	if err != nil {
		return nil, fmt.Errorf("error creating user: %w", err)
	}
	login := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	protoUserData, err := proto.Marshal(login)
	if err != nil {
		return nil, fmt.Errorf("error marshalling user data: %w", err)
	}

	lc.userInfo.SetData(login)
	return protoUserData, nil
}

func (lc *LanternCore) ActivationCode(email, resellerCode string) error {
	slog.Debug("Getting activation code")
	purchase, err := lc.apiClient.ActivationCode(context.Background(), email, resellerCode)
	if err != nil {
		return fmt.Errorf("error getting activation code: %w", err)
	}
	slog.Debug("ActivationCode response: ", "response", purchase)
	if purchase.Status != "ok" {
		return fmt.Errorf("activation code failed: %s", purchase.Status)
	}
	return nil
}

func (lc *LanternCore) DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	slog.Debug("Starting DigitalOcean private server flow")
	return privateserver.StartDigitalOceanPrivateServerFlow(events, lc.serverManager)
}

func (lc *LanternCore) GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return privateserver.StartGoogleCloudPrivateServerFlow(events, lc.serverManager)
}

func (lc *LanternCore) SelectAccount(account string) error {
	return privateserver.SelectAccount(account)
}

func (lc *LanternCore) SelectProject(project string) error {
	return privateserver.SelectProject(project)
}

func (lc *LanternCore) StartDeployment(location, serverName string) error {
	return privateserver.StartDepolyment(location, serverName)
}

func (lc *LanternCore) CancelDeployment() error {
	return privateserver.CancelDeployment()
}

func (lc *LanternCore) SelectedCertFingerprint(fp string) {
	privateserver.SelectedCertFingerprint(fp)
}

func (lc *LanternCore) AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return privateserver.AddServerManually(ip, port, accessToken, tag, lc.serverManager, events)
}
func (lc *LanternCore) InviteToServerManagerInstance(ip, port, accessToken, inviteName string) (string, error) {
	portInt, _ := strconv.Atoi(port)
	accessToken, err := privateserver.InviteToServerManagerInstance(ip, portInt, accessToken, inviteName, lc.serverManager)
	if err != nil {
		return "", fmt.Errorf("error inviting to server manager instance: %w", err)
	}
	slog.Debug("Invite to server manager instance:", "ip", ip, "port", portInt, "name", inviteName)
	return accessToken, nil
}

func (lc *LanternCore) RevokeServerManagerInvite(ip, port, accessToken, inviteName string) error {
	portInt, _ := strconv.Atoi(port)
	slog.Debug("Revoking invite:", "name", inviteName, "ip", ip, "port", port)
	return privateserver.RevokeServerManagerInvite(ip, portInt, accessToken, inviteName, lc.serverManager)
}

func Stub() Core {
	return &CoreStub{}
}

type CoreStub struct{}

// Make sure CoreStub implements the Core interface
var _ Core = (*CoreStub)(nil)

func (cs *CoreStub) AvailableFeatures() []byte {
	return []byte(`{}`)
}
func (cs *CoreStub) ReportIssue(email, issueType, description, device, model, logFilePath string) error {
	return nil
}
func (cs *CoreStub) CreateUser() (*api.UserDataResponse, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) UserData() ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) FetchUserData() ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) OAuthLoginUrl(provider string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) Login(email, password string) ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) SignUp(email, password string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) Logout(email string) ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) StartRecoveryByEmail(email string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) ValidateChangeEmailCode(email, code string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) CompleteChangeEmail(email, password, code string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) DeleteAccount(email, password string) ([]byte, error) {
	return nil, fmt.Errorf("not implemented")
}
func (cs *CoreStub) ActivationCode(email, resellerCode string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) StripeSubscription(email, planID string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) Plans(channel string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) StripeBillingPortalUrl() (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) AcknowledgeApplePurchase(receipt, planII string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) PaymentRedirect(provider, planId, email string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) StopVPN() error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) ConnectToServer(locationType, tag string, platIfce libbox.PlatformInterface, options *utils.Opts) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) IsVPNConnected() bool {
	return false
}
func (cs *CoreStub) AddSplitTunnelItem(filterType, item string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) RemoveSplitTunnelItem(filterType, item string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) DigitalOceanPrivateServer(events utils.PrivateServerEventListener) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) GoogleCloudPrivateServer(events utils.PrivateServerEventListener) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) SelectAccount(account string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) SelectProject(project string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) StartDepolyment(location, serverName string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) CancelDepolyment() error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) SelectedCertFingerprint(fp string) {
	// No-op for stub
}
func (cs *CoreStub) AddServerManagerInstance(ip, port, accessToken, tag string, events utils.PrivateServerEventListener) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
func (cs *CoreStub) RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error {
	return fmt.Errorf("not implemented")
}

func (cs *CoreStub) StartDeployment(location, serverName string) error {
	return fmt.Errorf("not implemented")
}
func (cs *CoreStub) CancelDeployment() error {
	return fmt.Errorf("not implemented")
}

func (cs *CoreStub) SubscriptionPaymentRedirectURL(redirectBody api.PaymentRedirectData) (string, error) {
	return "", fmt.Errorf("not implemented")
}

func (cs *CoreStub) StripeSubscriptionPaymentRedirect(subscriptionType, planID, email string) (string, error) {
	return "", fmt.Errorf("not implemented")
}
