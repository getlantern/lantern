package mobile

import (
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	_ "github.com/sagernet/gomobile/bind"
	"github.com/sagernet/sing-box/experimental/libbox"
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
