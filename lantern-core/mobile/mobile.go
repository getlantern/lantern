package mobile

import (
	"context"
	"path/filepath"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/pro"
	"github.com/getlantern/radiance/user"
	"github.com/getlantern/radiance/user/protos"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *radiance.Radiance
	proServer      *pro.Pro
	authClient     *user.User
)

// Create stipe subscription typs
type SubscriptionFrequancy string

const (
	SubscriptionTypeMonthly SubscriptionFrequancy = "monthly"
	SubscriptionTypeYearly  SubscriptionFrequancy = "yearly"
	SubscriptionTypeOneTime SubscriptionFrequancy = "onetime"
)

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
	radianceServer = r
	proServer = radianceServer.Pro()
	authClient = radianceServer.User()
	CreateUser()
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
	// defer func() {
	// 	if err := recover(); err != nil {
	// 		log.Errorf("Error creating user: %v", err)
	// 	}
	// }()
	log.Debug("Creating user")
	user, err := proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

func StripeSubscriptionPaymentRedirect(subType string) (*string, error) {
	ret := protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             "1y-usd",
		DeviceName:       "test",
		Email:            "test@getlantern.org",
		SubscriptionType: protos.SubscriptionType(subType),
	}
	stripeUrl, err := subscripationPaymentRedirect(&ret)
	if err != nil {
		return nil, log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("Stripe response: %v", stripeUrl)
	return stripeUrl, nil

}

func subscripationPaymentRedirect(redirectBody *protos.SubscriptionPaymentRedirectRequest) (*string, error) {
	rediret, err := proServer.SubscriptionPaymentRedirect(context.Background(), redirectBody)
	if err != nil {
		return nil, log.Errorf("Error getting subscription link: %v", err)
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return &rediret.Redirect, nil
}
