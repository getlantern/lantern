package client

import (
	"sync"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/lantern"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/util"

	"github.com/getlantern/golog"
)

// clientConfig holds global configuration settings for all clients.
var (
	log           = golog.LoggerFor("lantern-android.client")
	cf            = util.NewChainedAndFronted()
	configUpdates = make(chan *config.Config)
	cfgMutex      sync.Mutex
	exitCh        = make(chan error, 1)

	trackingCodes = map[string]string{
		"FireTweet": "UA-21408036-4",
		"Lantern":   "UA-21815217-14",
	}

	defaultClient *lantern.Lantern
)

// newClient creates a proxy client.
func newClient(addr, appName string, androidProps map[string]string, configDir string) (*lantern.Lantern, error) {

	logging.ConfigureAndroid(client.LogglyToken, client.LogglyTag, androidProps)

	cfgFn := func(cfg *config.Config) {

	}

	return lantern.Start(false, true, false, true, cfgFn)
}
