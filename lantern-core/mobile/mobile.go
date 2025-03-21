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

func SetupRadiance(configDir string, platform libbox.PlatformInterface) {
	radianceMutex.Lock()
	defer radianceMutex.Unlock()
	r, err := radiance.NewRadiance(configDir, platform)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r
	log.Debug("Radiance setup successfully")
}

func StartVPN() {
	defer func() {
		if r := recover(); r != nil {
			fmt.Printf("Recovered from panic in StartVPN: %v\nStack trace:\n%s\n", r, debug.Stack())
		}
	}()

	log.Debug("Starting VPN")
	radianceServer.StartVPN()
}

func StopVPN() {
	radianceServer.StopVPN()
}

func GetAvailableServers() {
	radianceServer.GetAvailableServers(context.Background())
}
