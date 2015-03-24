package autoupdate

import (
	"net/http"
	"sync"
	"time"

	"github.com/getlantern/autoupdate"
	"github.com/getlantern/golog"
)

const (
	serviceURL = "https://update.lantern.org/update"
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
	watching   = false

	applyNextAttemptTime = time.Hour * 2
)

func Configure(newClient *http.Client) {
	cfgMutex.Lock()
	defer cfgMutex.Unlock()

	if newClient == nil {
		return
	}

	httpClient = newClient

	if !watching {
		watchForUpdate()
	}
}

func watchForUpdate() {
	watching = true
	for watching {
		applyNext()
		// At this point we either updated the binary or failed to recover from a
		// update error, let's wait a bit before looking for a another update.
		time.Sleep(applyNextAttemptTime)
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
			log.Debugf("autoupdate: Error getting update: %v", err)
			return
		}
		log.Debugf("autoupdate: Got update.")
	}
}
