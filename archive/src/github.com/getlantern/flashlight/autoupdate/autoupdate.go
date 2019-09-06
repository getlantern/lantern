package autoupdate

import (
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/autoupdate"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

var (
	updateServerURL = "https://update.getlantern.org"
	PublicKey       []byte
	Version         string
)

var (
	log = golog.LoggerFor("flashlight.autoupdate")

	cfgMutex    sync.RWMutex
	updateMutex sync.Mutex

	httpClient *http.Client
	watching   int32

	applyNextAttemptTime = time.Hour * 2
)

// Configure sets the CA certificate to pin for the TLS auto-update connection.
func Configure(updateURL, updateCA string) {
	setUpdateURL(updateURL)

	enableAutoupdate(updateCA)
}

func setUpdateURL(url string) {
	if url == "" {
		return
	}
	cfgMutex.Lock()
	defer cfgMutex.Unlock()
	updateServerURL = url
}

func getUpdateURL() string {
	cfgMutex.RLock()
	defer cfgMutex.RUnlock()
	return updateServerURL + "/update"
}

func enableAutoupdate(updateCA string) {
	rt, err := proxied.ChainedNonPersistent(updateCA)
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
			URL:            getUpdateURL(),
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
