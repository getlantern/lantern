package mobile

import (
	"context"
	"encoding/json"
	"path/filepath"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/pro"
	"github.com/getlantern/radiance/user"
	"github.com/getlantern/radiance/user/protos"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *lanternService
)

type lanternService struct {
	*radiance.Radiance
	proServer  *pro.Pro
	authClient *user.User
	userConfig common.UserConfig
}

func SetupRadiance(dataDir, deviceid string, platform libbox.PlatformInterface) error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	r, err := radiance.NewRadiance(client.Options{
		LogDir:   filepath.Join(dataDir, "logs"),
		DataDir:  dataDir,
		PlatIfce: platform,
		DeviceID: deviceid,
	})
	if err != nil {
		return log.Errorf("Unable to create Radiance: %v", err)

	}
	radianceServer = &lanternService{
		Radiance:   r,
		proServer:  r.Pro(),
		authClient: r.User(),
		userConfig: r.UserConfig(),
	}
	if radianceServer.userConfig.LegacyID() == 0 {
		CreateUser()
	}
	log.Debug("Radiance setup successfully")
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

// todo make sure to add retry logic
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
	stripeUrl, err := subscripationPaymentRedirect(&ret)
	if err != nil {
		return "", log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("Stripe response: %v", stripeUrl)
	return stripeUrl, nil
}

func Plans() (string, error) {
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

func subscripationPaymentRedirect(redirectBody *protos.SubscriptionPaymentRedirectRequest) (string, error) {
	rediret, err := radianceServer.proServer.SubscriptionPaymentRedirect(context.Background(), redirectBody)
	if err != nil {
		return "", log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return rediret.Redirect, nil
}
