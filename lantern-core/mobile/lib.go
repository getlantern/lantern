package mobile

import (
	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/sagernet/sing-box/experimental/libbox"
)

var (
	log            = golog.LoggerFor("lantern-outline.native")
	radianceServer *radiance.Radiance
)

func SetupRadiance(platform libbox.PlatformInterface) {
	r, err := radiance.NewRadiance(platform)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)
		return
	}
	radianceServer = r
	log.Debug("Radiance setup successfully")
}
