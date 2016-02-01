// Package lantern provides an embeddable client-side web proxy
package lantern

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/getlantern/flashlight"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("lantern")

	startOnce sync.Once
)

// Start starts a client proxy at a random address. It blocks up till the given
// timeout waiting for the proxy to listen, and returns the address at which it
// is listening. If the proxy doesn't start within the given timeout, this
// method returns an error.
//
// If a Lantern proxy is already running within this process, that proxy is
// reused.
//
// Note - this does not wait for the entire initialization sequence to finish,
// just for the proxy to be listening. Once the proxy is listening, one can
// start to use it, even as it finishes its initialization sequence. However,
// initial activity may be slow, so clients with low read timeouts may
// time out.
func Start(configDir string, timeoutMillis int) (string, error) {
	startOnce.Do(func() {
		go run(configDir)
	})
	addr, ok := client.Addr(time.Duration(timeoutMillis) * time.Millisecond)
	if !ok {
		return "", fmt.Errorf("Proxy didn't start within given timeout")
	}
	return addr.(string), nil
}

// AddLoggingMetadata adds metadata for reporting to cloud logging services
func AddLoggingMetadata(key, value string) {
	logging.SetExtraLogglyInfo(key, value)
}

func run(configDir string) {
	err := os.MkdirAll(configDir, 0755)
	if os.IsExist(err) {
		log.Errorf("Unable to create configDir at %v: %v", configDir, err)
		return
	}
	flashlight.Run("localhost:0",
		configDir,
		false,
		func() bool { return true },
		make(map[string]interface{}),
		func(cfg *config.Config) bool { return true },
		func(cfg *config.Config) {},
		func(cfg *config.Config) {},
		func(err error) {},
	)
}
