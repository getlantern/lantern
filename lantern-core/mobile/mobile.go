package mobile

import (
	"context"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/sagernet/sing-box/experimental/libbox"
	_ "golang.org/x/mobile/bind"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radiancMutex   = sync.Mutex{}
	radianceServer *radiance.Radiance
)

func SetupRadiance(platform libbox.PlatformInterface) {
	radiancMutex.Lock()
	defer radiancMutex.Unlock()
	r, err := radiance.NewRadiance(platform)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r
	log.Debug("Radiance setup successfully")
}

func StartVPN() {
	radianceServer.StartVPN()
}

func StopVPN() {
	radianceServer.StopVPN()
}

func GetAvailableServers() {
	radianceServer.GetAvailableServers(context.Background())
}
