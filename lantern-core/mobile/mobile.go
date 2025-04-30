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
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/common"

	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *lanternService
	apiHandler     *apiService
	setupOnce      sync.Once
)

type lanternService struct {
	*radiance.Radiance
	userConfig common.UserInfo
}
type apiService struct {
	proServer  *api.Pro
	user       *api.User
	userConfig common.UserInfo
}
type Opts struct {
	DataDir  string
	Deviceid string
	Locale   string
}

func enableSplitTunneling() bool {
	return runtime.GOOS == "android"
}
func SetupRadiance(opts *Opts, platform libbox.PlatformInterface) error {
	var innerErr error
	setupOnce.Do(func() {
		logDir := filepath.Join(opts.DataDir, "logs")
		if err := os.MkdirAll(opts.DataDir, 0o777); err != nil {
			log.Errorf("unable to create data directory: %v", err)
		}
		if err := os.MkdirAll(logDir, 0o777); err != nil {
			log.Errorf("unable to create log directory: %v", err)
		}
		clientOpts := client.Options{
			LogDir:               logDir,
			DataDir:              opts.DataDir,
			PlatIfce:             platform,
			DeviceID:             opts.Deviceid,
			Locale:               opts.Locale,
			EnableSplitTunneling: enableSplitTunneling(),
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
		}
		log.Debug("Radiance setup successfully")
	})

	if innerErr != nil {
		return innerErr
	}
	return nil
}

func NewAPIHandler(opts *Opts) error {
	logDir := filepath.Join(opts.DataDir, "logs")
	clientOpts := client.Options{
		LogDir:               logDir,
		DataDir:              opts.DataDir,
		DeviceID:             opts.Deviceid,
		Locale:               opts.Locale,
		PlatIfce:             nil,
		EnableSplitTunneling: false,
	}
	apis, err := radiance.NewAPIHandler(clientOpts)
	if err != nil {
		return fmt.Errorf("unable to create API handler: %v", err)
	}
	apiHandler = &apiService{
		proServer:  apis.ProServer,
		user:       apis.User,
		userConfig: apis.UserInfo,
	}
	log.Debugf("User config: %v", apiHandler.userConfig)
	if apiHandler.userConfig.LegacyID() == 0 {
		log.Debug("Creating user")
		CreateUser()
	}
	log.Debugf("API handler setup successfully")
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
	if radianceServer == nil {
		return log.Error("Radiance not setup")
	}
	err := radianceServer.StartVPN()
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
	if radianceServer == nil {
		return log.Error("Radiance not setup")
	}
	er := radianceServer.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

func IsVPNConnected() bool {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if radianceServer == nil {
		return false
	}
	return radianceServer.ConnectionStatus()
}

// Todo make sure to add retry logic
// we need to make sure that the user is created before we can use the radiance server
func CreateUser() error {
	log.Debug("Creating user")
	user, err := apiHandler.proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

// OAuth Methods
func OAuthLoginUrl(provider string) (string, error) {
	log.Debug("Getting OAuth login URL")
	oauthLoginUrl, err := apiHandler.user.OAuthLoginUrl(context.Background(), provider)
	if err != nil {
		return "", log.Errorf("Error getting OAuth login URL: %v", err)
	}
	log.Debugf("OAuthLoginUrl response: %v", oauthLoginUrl.Redirect)
	return oauthLoginUrl.Redirect, nil
}

func StripeSubscription() (string, error) {
	defer func() {
		if err := recover(); err != nil {
			log.Errorf("Error creating stripe subscription: %v", err)
		}
	}()
	log.Debug("Creating stripe subscription")
	body := protos.SubscriptionRequest{
		Email:   "test@getlantern.org",
		Name:    "test",
		PriceId: "price_1RCg464XJ6zbDKY5T6kqbMC6",
	}
	stripeSubscription, err := apiHandler.proServer.StripeSubscription(context.Background(), &body)
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

// Create subscription link for stripe
// usege for macos, linux, windows
func StripeSubscriptionPaymentRedirect(subType string) (string, error) {
	ret := protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             "1y-usd",
		DeviceName:       "test",
		Email:            "test@getlantern.org",
		SubscriptionType: protos.SubscriptionType(subType),
	}
	stripeUrl, err := subscriptionPaymentRedirect(&ret)
	if err != nil {
		return "", log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("Stripe response: %v", stripeUrl)
	return stripeUrl, nil
}

func Plans() (string, error) {
	log.Debug("Getting plans")
	plans, err := apiHandler.proServer.Plans(context.Background())
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
	rediret, err := apiHandler.proServer.SubscriptionPaymentRedirect(context.Background(), redirectBody)
	if err != nil {
		return "", log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return rediret.Redirect, nil
}
