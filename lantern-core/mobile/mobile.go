package mobile

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"sync"

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

var (
	log            = golog.LoggerFor("lantern-outline.mobile")
	radianceMutex  = sync.Mutex{}
	setupRadiance  sync.Once
	storeRadiance  = sync.Map{}
	radianceServer *lanternService
)

const (
	serverManagerKey      = "server-manager"
	spiltTunnelHandlerKey = "splitTunnelHandler"
)

type lanternService struct {
	*radiance.Radiance
	userConfig common.UserInfo
	apiClient  *api.APIClient
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}

func SetupRadiance(opts *utils.Opts) error {
	defer func() {
		if r := recover(); r != nil {
			log.Errorf("Recovered from panic in SetupRadiance: %v", r)
		}
	}()
	var innerErr error
	setupRadiance.Do(func() {
		logDir := filepath.Join(opts.DataDir, "logs")
		if err := os.MkdirAll(opts.DataDir, 0o777); err != nil {
			log.Errorf("unable to create data directory: %v", err)
		}
		if err := os.MkdirAll(logDir, 0o777); err != nil {
			log.Errorf("unable to create log directory: %v", err)
		}
		clientOpts := radiance.Options{
			LogDir:   logDir,
			DataDir:  opts.DataDir,
			Locale:   opts.Locale,
			DeviceID: opts.Deviceid,
		}
		r, err := radiance.NewRadiance(clientOpts)
		log.Debugf("Paths: %s %s", logDir, opts.DataDir)
		if err != nil {
			innerErr = fmt.Errorf("unable to create Radiance: %v", err)
			return
		}

		sth, sthErr := vpn.NewSplitTunnelHandler()
		if sthErr != nil {
			innerErr = fmt.Errorf("unable to create split tunnel handler: %v", sthErr)
		}
		storeRadiance.Store(spiltTunnelHandlerKey, sth)
		serverManager, mngErr := servers.NewManager(opts.DataDir)
		if mngErr != nil {
			innerErr = fmt.Errorf("unable to create server manager: %v", mngErr)
			return
		}
		storeRadiance.Store(serverManagerKey, serverManager)
		radianceServer = &lanternService{
			Radiance:   r,
			userConfig: r.UserInfo(),
			apiClient:  r.APIHandler(),
		}
		log.Debug("Radiance setup successfully")
		if radianceServer.userConfig.LegacyID() == 0 {
			log.Debug("Creating user")
			CreateUser()
		}
		FetchUserData()
	})

	if innerErr != nil {
		return innerErr
	}
	return nil
}

func getServerManager() (*servers.Manager, error) {
	if v, ok := storeRadiance.Load(serverManagerKey); ok {
		if sm, ok := v.(*servers.Manager); ok {
			return sm, nil
		}
		return nil, fmt.Errorf("server manager not found")
	}
	return nil, fmt.Errorf("server manager not found")
}

func getSplitTunnelHandler() (*vpn.SplitTunnel, error) {
	if v, ok := storeRadiance.Load(spiltTunnelHandlerKey); ok {
		if sth, ok := v.(*vpn.SplitTunnel); ok {
			return sth, nil
		}
		return nil, fmt.Errorf("split tunnel handler not found")
	}
	return nil, fmt.Errorf("split tunnel handler not found")
}

func AvailableFeatures() []byte {
	features := radianceServer.Features()
	log.Debugf("Available features: %v", features)
	jsonBytes, err := json.Marshal(features)
	if err != nil {
		log.Errorf("Error marshalling features: %v", err)
		return nil
	}
	return jsonBytes
}

func IsRadianceConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	return radianceServer != nil
}

func StartVPN(platform libbox.PlatformInterface, opts *utils.Opts) error {
	log.Debug("Starting VPN")
	radianceMutex.Lock()
	defer radianceMutex.Unlock()

	err := vpn_tunnel.StartVPN(platform, opts)
	if err != nil {
		log.Errorf("Error starting VPN: %v", err)
		return err
	}
	return nil
}

func StopVPN() error {
	log.Debug("Stopping VPN")
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
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
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	err := vpn_tunnel.ConnectToServer(locationType, tag, platIfce, options)
	if err != nil {
		return log.Errorf("Error setting private server: %v", err)
	}
	log.Debugf("Private server set with tag: %s", tag)
	return nil
}

func getLanternService() (*lanternService, error) {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if radianceServer == nil {
		return nil, fmt.Errorf("radiance not initialized")
	}
	return radianceServer, nil
}

func IsVPNConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	return vpn_tunnel.IsVPNRunning()
}

func AddSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	spiltHandler, sErr := getSplitTunnelHandler()
	if sErr != nil {
		return log.Errorf("Error getting split tunnel handler: %v", sErr)
	}
	if err := spiltHandler.AddItem(filterType, item); err != nil {
		return fmt.Errorf("error adding item: %v", err)
	}
	log.Debugf("added %s split tunneling item %s", filterType, item)
	return nil
}

func RemoveSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	spiltHandler, sErr := getSplitTunnelHandler()
	if sErr != nil {
		return log.Errorf("Error getting split tunnel handler: %v", sErr)
	}
	if err := spiltHandler.RemoveItem(filterType, item); err != nil {
		return fmt.Errorf("error removing item: %v", err)
	}
	log.Debugf("removed %s split tunneling item %s", filterType, item)
	return nil
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() (*api.UserDataResponse, error) {
	radianceServer, err := getLanternService()
	if err != nil {
		return nil, err
	}
	log.Debug("Creating user")
	user, err := radianceServer.apiClient.NewUser(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return nil, log.Errorf("Error creating user: %v", err)
	}
	return user, nil
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	radianceServer, err := getLanternService()
	if err != nil {
		return nil, err
	}
	user, err := radianceServer.userConfig.GetData()
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
	//this call will also save the user data in the user config
	// so we can use it later
	user, err := radianceServer.apiClient.UserData(context.Background())
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
	oauthLoginUrl, err := radianceServer.apiClient.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", log.Errorf("Error getting OAuth login URL: %v", err)
	}
	log.Debugf("OAuthLoginUrl response: %v", oauthLoginUrl)
	return oauthLoginUrl, nil
}

func OAuthLoginCallback(oAuthToken string) ([]byte, error) {
	log.Debug("Getting OAuth login callback")
	userInfo, err := utils.DecodeJWT(oAuthToken)
	if err != nil {
		return nil, log.Errorf("Error decoding JWT: %v", err)
	}
	// Temporary  set user data to so api can read it
	login := &protos.LoginResponse{
		LegacyID:    userInfo.LegacyUserId,
		LegacyToken: userInfo.LegacyToken,
	}
	radianceServer.userConfig.SetData(login)
	///Get user data from api this will also save data in user config
	user, err := radianceServer.apiClient.UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	userResponse := &protos.LoginResponse{
		Id:             userInfo.Email,
		EmailConfirmed: true,
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	radianceServer.userConfig.SetData(userResponse)
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

func StripeSubscription(email, planId string) (string, error) {
	log.Debug("Creating stripe subscription")
	stripeSubscription, err := radianceServer.apiClient.NewStripeSubscription(context.Background(), email, planId)
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
	plans, err := radianceServer.apiClient.SubscriptionPlans(context.Background(), channel)
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
	billingPortal, err := radianceServer.apiClient.StripeBillingPortalUrl()
	if err != nil {
		return "", log.Errorf("Error getting stripe billing portal: %v", err)
	}
	log.Debugf("StripeBillingPortal response: %v", billingPortal)
	return billingPortal, nil
}

func AcknowledgeGooglePurchase(purchaseToken, planId string) error {
	log.Debugf("Purchase token: %s planId %s", purchaseToken, planId)
	params := map[string]string{
		"purchaseToken": purchaseToken,
		"planId":        planId,
	}
	status, _, err := radianceServer.apiClient.VerifySubscription(context.Background(), api.GoogleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge google purchase: %v", status)
	return nil
}

func AcknowledgeApplePurchase(receipt, planId string) error {
	log.Debugf("Apple receipt: %s planId %s", receipt, planId)
	params := map[string]string{
		"receipt": receipt,
		"planId":  planId,
	}
	status, _, err := radianceServer.apiClient.VerifySubscription(context.Background(), api.AppleService, params)
	if err != nil {
		return log.Errorf("Error acknowledging: %v", err)
	}
	log.Debugf("acknowledge apple purchase: %v", status)
	return nil
}

func PaymentRedirect(provider, planId, email string) (string, error) {
	log.Debug("Payment redirect")
	deviceName := radianceServer.userConfig.DeviceID()
	body := api.PaymentRedirectData{
		Provider:   provider,
		Plan:       planId,
		DeviceName: deviceName,
		Email:      email,
	}
	paymentRedirect, err := radianceServer.apiClient.PaymentRedirect(context.Background(), body)
	if err != nil {
		return "", log.Errorf("Error getting payment redirect: %v", err)
	}
	log.Debugf("Payment redirect response: %v", paymentRedirect)
	return paymentRedirect, nil
}

/// User management apis

func Login(email, password string) ([]byte, error) {
	log.Debug("Logging in user")
	deviceId := radianceServer.userConfig.DeviceID()
	loginResponse, err := radianceServer.apiClient.Login(context.Background(), email, password, deviceId)
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
	err := radianceServer.apiClient.SignUp(context.Background(), email, password)
	if err != nil {
		return log.Errorf("Error signing up: %v", err)
	}
	return nil
}

func Logout(email string) ([]byte, error) {
	log.Debug("Logging out")
	err := radianceServer.apiClient.Logout(context.Background(), email)
	if err != nil {
		return nil, log.Errorf("Error logging out: %v", err)
	}
	//this call will save data
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
	err := radianceServer.apiClient.StartRecoveryByEmail(context.Background(), email)
	if err != nil {
		return log.Errorf("Error starting change email: %v", err)
	}
	return nil
}

// This will validate the recovery code sent to the user's email
func ValidateChangeEmailCode(email, code string) error {
	log.Debug("Validating change email code")
	err := radianceServer.apiClient.ValidateEmailRecoveryCode(context.Background(), email, code)
	if err != nil {
		return log.Errorf("Error validating change email code: %v", err)
	}
	log.Debugf("ValidateChangeEmailCode Sucessful for email: %s", email)
	return nil
}

// This will complete the email recovery by setting the new password
func CompleteChangeEmail(email, password, code string) error {
	log.Debug("Completing change email")
	err := radianceServer.apiClient.CompleteRecoveryByEmail(context.Background(), email, password, code)
	if err != nil {
		return log.Errorf("Error completing change email: %v", err)
	}
	return nil
}

func DeleteAccount(email, password string) ([]byte, error) {
	log.Debug("Deleting account")
	err := radianceServer.apiClient.DeleteAccount(context.Background(), email, password)
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
	radianceServer.userConfig.SetData(login)
	return protoUserData, nil
}

func ActivationCode(email, resellerCode string) error {
	log.Debug("Getting activation code")
	purchase, err := radianceServer.apiClient.ActivationCode(context.Background(), email, resellerCode)
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
	mgn, err := getServerManager()
	if err != nil {
		return log.Errorf("Error getting server manager: %v", err)
	}
	return privateserver.StartDigitalOceanPrivateServerFlow(events, mgn)
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
	mgn, err := getServerManager()
	if err != nil {
		return log.Errorf("Error getting server manager: %v", err)
	}
	return privateserver.AddServerManually(ip, port, accessToken, tag, mgn, events)
}
func InviteToServerManagerInstance(ip string, port string, accessToken string, inviteName string) (string, error) {
	mgn, mErr := getServerManager()
	if mErr != nil {
		return "", log.Errorf("Error getting server manager: %v", mErr)
	}
	portInt, _ := strconv.Atoi(port)
	accessToken, err := privateserver.InviteToServerManagerInstance(ip, portInt, accessToken, inviteName, mgn)
	if err != nil {
		return "", log.Errorf("Error inviting to server manager instance: %v", err)
	}
	log.Debugf("Invite to server manager instance %s:%d with name %s", ip, portInt, inviteName)
	return accessToken, nil
}

func RevokeServerManagerInvite(ip string, port string, accessToken string, inviteName string) error {
	mgn, err := getServerManager()
	if err != nil {
		return log.Errorf("Error getting server manager: %v", err)
	}
	portInt, _ := strconv.Atoi(port)
	log.Debugf("Revoking invite %s for server %s:%d", inviteName, ip, port)
	return privateserver.RevokeServerManagerInvite(ip, portInt, accessToken, inviteName, mgn)
}
