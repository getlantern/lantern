package autoupdate

import (
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/autoupdate"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
)

const (
	serviceURL = "https://update.getlantern.org/update"
)

var (
	PublicKey []byte
	Version   string
)

var (
	log = golog.LoggerFor("flashlight.autoupdate")

	cfgMutex    sync.Mutex
	updateMutex sync.Mutex

	httpClient *http.Client
	watching   int32 = 0

	applyNextAttemptTime = time.Hour * 2
)

func Configure(cfg *config.Config) {
	cfgMutex.Lock()

	go func() {
		enableAutoupdate(cfg)
		cfgMutex.Unlock()
	}()

}

func enableAutoupdate(cfg *config.Config) {
	var err error

	httpClient, err = util.HTTPClient(cfg.CloudConfigCA, client.Addr)
	if err != nil {
		log.Errorf("Could not create proxied HTTP client, disabling auto-updates: %v", err)
		return
	}

	go watchForUpdate()
}

func watchForUpdate() {
	if atomic.LoadInt32(&watching) < 1 {

		atomic.AddInt32(&watching, 1)

		log.Debugf("Software version: %s", Version)

		for {
			applyNext()
			// At this point we either updated the binary or failed to recover from a
			// update error, let's wait a bit before looking for a another update.
			time.Sleep(applyNextAttemptTime)
		}
	}
}

func applyNext() {
	updateMutex.Lock()
	defer updateMutex.Unlock()

	if httpClient != nil {
		err := autoupdate.ApplyNext(&autoupdate.Config{
			CurrentVersion: Version,
			URL:            serviceURL,
			PublicKey:      PublicKey,
			HTTPClient:     httpClient,
		})
		if err != nil {
			log.Debugf("Error getting update: %v", err)
			return
		}
		log.Debugf("Got update.")
	}
}
