package mobile

import (
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *radiance.Radiance
	setupOnce      sync.Once
)

func SetupRadiance(logDir string, platform libbox.PlatformInterface) {
	setupOnce.Do(func() {
		log.Debugf("Creating new instance of radiance with log dir and platform")
		r, err := radiance.NewRadiance(logDir, platform)
		if err != nil {
			log.Errorf("Unable to create Radiance: %v", err)
			return
		}
		radianceServer = r
		log.Debug("Radiance setup successfully")
	})
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
