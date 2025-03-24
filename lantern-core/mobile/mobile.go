package mobile

import (
	"context"
	"fmt"
	"runtime/debug"
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
)

func SetupRadiance(logDir string, platform libbox.PlatformInterface) {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	r, err := radiance.NewRadiance(logDir, platform)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r
	log.Debug("Radiance setup successfully")
}

func StartVPN() error {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("Recovered from panic in StartVPN: %v\nStack trace:\n%s\n", r, debug.Stack())
		}
	}()

	log.Debug("Starting VPN")
	err := radianceServer.StartVPN()
	if err != nil {
		return log.Errorf("Error starting VPN: %v", err)
	}
	return nil
}

func StopVPN() error {
	er := radianceServer.StopVPN()
	if er != nil {
		log.Errorf("Error stopping VPN: %v", er)
	}
	return nil
}

func GetAvailableServers() {
	radianceServer.GetAvailableServers(context.Background())
}
