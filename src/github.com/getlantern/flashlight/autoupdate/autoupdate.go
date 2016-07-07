package autoupdate

import (
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/autoupdate"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("flashlight.autoupdate")

	updateServerURL = config.UpdateServerURL
	PublicKey       []byte
	Version         string

	cfgMutex    sync.Mutex
	updateMutex sync.Mutex

	httpClient *http.Client
	watching   int32 = 0

	applyNextAttemptTime = time.Hour * 2
)

func init() {
	// Passing public key and version to the autoupdate service.
	PublicKey = []byte(autoupdate.PackagePublicKey)
}

func Configure(cfg *config.Config) {
	cfgMutex.Lock()

	if cfg.UpdateServerURL != "" {
		updateServerURL = cfg.UpdateServerURL
	}

	go func() {
		enableAutoupdate(cfg)
		cfgMutex.Unlock()
	}()

}

func enableAutoupdate(cfg *config.Config) {
	rt, err := proxied.ChainedNonPersistent(cfg.CloudConfigCA)
	if err != nil {
		log.Errorf("Could not create proxied HTTP client, disabling auto-updates: %v", err)
		return
	}
	httpClient = &http.Client{
		Transport: rt,
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
			URL:            updateServerURL + "/update",
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
