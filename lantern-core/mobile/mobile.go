package mobile

import (
	"errors"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/mobile/libbox"
	"github.com/getlantern/radiance"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceMutex  = sync.Mutex{}
	radianceServer *radiance.Radiance
)

func SetupRadiance(configDir string, platform libbox.PlatformInterface) {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()

	r, err := radiance.NewRadiance(configDir, &singBoxPlatformWrapper{platform: platform})
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r

	log.Debug("Radiance setup successfully")
}

func StartVPN() error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	if radianceServer == nil {
		return errors.New("radiance server not initialized")
	}
	log.Debug("Starting VPN")
	err := radianceServer.StartVPN()
	if err != nil {
		log.Errorf("Error starting VPN: %v", err)
		return err
	}
	return nil
}

func StopVPN() error {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	log.Debug("Stopping VPN")
	if radianceServer == nil {
		return errors.New("radiance server not initialized")
	}
	er := radianceServer.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

func IsVPNConncted() bool {
	return radianceServer.ConnectionStatus()
}
