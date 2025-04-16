package mobile

import (
	"context"
	"path/filepath"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/user/protos"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *radiance.Radiance
)

func SetupRadiance(dataDir, deviceid string, platform libbox.PlatformInterface) {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	r, err := radiance.NewRadiance(client.Options{
		LogDir:   filepath.Join(dataDir, "logs"),
		DataDir:  dataDir,
		PlatIfce: platform,
		DeviceID: deviceid,
	})
	log.Debugf("Paths: %s %s", filepath.Join(dataDir, "logs"), dataDir)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r
	CreateUser()
	log.Debug("Radiance setup successfully")
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

func CreateUser() error {
	defer func() {
		if err := recover(); err != nil {
			log.Errorf("Error creating user: %v", err)
		}
	}()
	log.Debug("Creating user")
	proServer := radianceServer.Pro()
	user, err := proServer.UserCreate(context.Background())
	log.Debugf("UserCreate response: %v", user)
	if err != nil {
		return log.Errorf("Error creating user: %v", err)
	}
	return nil
}

func SubscripationPaymentRedirect() string {
	proServer := radianceServer.Pro()
	ret := protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             "1y-usd",
		DeviceName:       "test",
		Email:            "test@getlantern.org",
		SubscriptionType: "monthly",
	}

	rediret, err := proServer.SubscriptionPaymentRedirect(context.Background(), &ret)
	if err != nil {
		log.Errorf("Error getting subscription link: %v", err)
		return ""
	}
	log.Debugf("SubscriptionPaymentRedirect response: %v", rediret)
	return rediret.Redirect
}
