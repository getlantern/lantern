package mobile

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/common"
	"google.golang.org/protobuf/proto"

	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *lanternService
	vpnClient      client.VPNClient

	setupRadiance   sync.Once
	setupRVPNClient sync.Once
)

type lanternService struct {
	*radiance.Radiance
	userConfig common.UserInfo
	proServer  *api.Pro
	user       *api.User
}
type Opts struct {
	DataDir  string
	Deviceid string
	Locale   string
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}
func SetupRadiance(opts *Opts) error {
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

		radianceServer = &lanternService{
			Radiance:   r,
			userConfig: r.UserInfo(),
			proServer:  r.APIHandler().ProServer,
			user:       r.APIHandler().User,
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

func NewVPNClient(opts *Opts, platform libbox.PlatformInterface) error {
	var innerErr error
	setupRVPNClient.Do(func() {
		logDir := filepath.Join(opts.DataDir, "logs")
		client, err := client.NewVPNClient(opts.DataDir, logDir, platform, enableSplitTunneling())
		if err != nil {
			innerErr = fmt.Errorf("unable to create vpn client: %v", err)
			return
		}
		vpnClient = client
		log.Debugf("VPN client setup successfully")
	})
	if innerErr != nil {
		return innerErr
	}
	return nil
}

func IsRadianceConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	return radianceServer != nil
}

func StartVPN() error {
	log.Debug("Starting VPN")
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("VPN client not setup")
	}
	err := vpnClient.StartVPN()
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
	if vpnClient == nil {
		return log.Error("VPN client not setup")
	}
	er := vpnClient.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

func IsVPNConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return false
	}
	return vpnClient.ConnectionStatus()
}

func AddSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("Radiance not setup")
	}

	if err := vpnClient.SplitTunnelHandler().AddItem(filterType, item); err != nil {
		return fmt.Errorf("error adding item: %v", err)
	}
	log.Debugf("added %s split tunneling item %s", filterType, item)
	return nil
}

func RemoveSplitTunnelItem(filterType, item string) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if vpnClient == nil {
		return log.Error("Radiance not setup")
	}

	if err := vpnClient.SplitTunnelHandler().RemoveItem(filterType, item); err != nil {
		return fmt.Errorf("error removing item: %v", err)
	}
	log.Debugf("removed %s split tunneling item %s", filterType, item)
	return nil
}

// User Methods
// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() error {
	log.Debug("Creating user")
	user, err := radianceServer.proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

// this will return the user data from the user config
func UserData() ([]byte, error) {
	user, err := radianceServer.userConfig.GetUserData()
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	bytes, err := proto.Marshal(user)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

// GetUserData will get the user data from the server
func FetchUserData() (*protos.UserDataResponse, error) {
	log.Debug("Getting user data")
	//this call will also save the user data in the user config
	// so we can use it later
	user, err := radianceServer.proServer.UserData(context.Background())
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	return user, nil
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	log.Debug("Getting OAuth login URL")
	oauthLoginUrl, err := radianceServer.user.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", log.Errorf("Error getting OAuth login URL: %v", err)
	}
	log.Debugf("OAuthLoginUrl response: %v", oauthLoginUrl.Redirect)
	return oauthLoginUrl.Redirect, nil
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
	radianceServer.userConfig.Save(login)
	///Get user data from api this will also save data in user config
	user, err := FetchUserData()
	if err != nil {
		return nil, log.Errorf("Error getting user data: %v", err)
	}
	log.Debugf("UserData response: %v", user)
	userResponse := &protos.LoginResponse{
		LegacyID:       user.UserId,
		LegacyToken:    user.Token,
		LegacyUserData: user.LoginResponse_UserData,
	}
	bytes, err := proto.Marshal(userResponse)
	if err != nil {
		return nil, log.Errorf("Error marshalling user data: %v", err)
	}
	return bytes, nil
}

func StripeSubscription(email, planId string) (string, error) {
	log.Debug("Creating stripe subscription")
	body := protos.SubscriptionRequest{
		Email:   email,
		Name:    email,
		PriceId: planId,
	}
	stripeSubscription, err := radianceServer.proServer.StripeSubscription(context.Background(), &body)
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

// // Create subscription link for stripe
// // usege for macos, linux, windows
// func StripeSubscriptionPaymentRedirect(planID, provider, email, subType string) (string, error) {
// 	ret := protos.SubscriptionPaymentRedirectRequest{
// 		Provider:         "stripe",
// 		Plan:             "1y-usd",
// 		DeviceName:       "test",
// 		Email:            "test@getlantern.org",
// 		SubscriptionType: protos.SubscriptionType(subType),
// 	}
// 	stripeUrl, err := subscriptionPaymentRedirect(&ret)
// 	if err != nil {
// 		return "", log.Errorf("Error getting subscription link: %v", err)
// 	}
// 	log.Debugf("Stripe response: %v", stripeUrl)
// 	return stripeUrl, nil
// }

func Plans() (string, error) {
	defer func() {
		if err := recover(); err != nil {
			log.Errorf("Error creating stripe subscription: %v", err)
		}
	}()
	log.Debug("Getting plans")
	plans, err := radianceServer.proServer.Plans(context.Background())
	if err != nil {
		return "", log.Errorf("Error getting plans: %v", err)
	}
	log.Debugf("Plans response: %v", plans)
	jsonData, err := json.Marshal(plans)
	if err != nil {
		return "", log.Errorf("Error marshalling plans: %v", err)
	}
	// Convert bytes to string and print
	return string(jsonData), nil
}

func subscriptionPaymentRedirect(redirectBody *protos.SubscriptionPaymentRedirectRequest) (string, error) {
	rediret, err := radianceServer.proServer.SubscriptionPaymentRedirect(context.Background(), redirectBody)
	if err != nil {
		return "", log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return rediret.Redirect, nil
}
