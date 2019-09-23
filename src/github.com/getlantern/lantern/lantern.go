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
	"github.com/getlantern/protected"
	"github.com/getlantern/tlsdialer"
)

var (
	log = golog.LoggerFor("lantern")

	startOnce sync.Once
)

type SocketProtector interface {
	Protect(fileDescriptor int) error
}

// ProtectConnections allows connections made by Lantern to be protected from
// routing via a VPN. This is useful when running Lantern as a VPN on Android,
// because it keeps Lantern's own connections from being captured by the VPN and
// resulting in an infinite loop.
func ProtectConnections(dnsServer string, protector SocketProtector) {
	protected.Configure(protector.Protect, dnsServer)
	tlsdialer.OverrideResolve(protected.Resolve)
	tlsdialer.OverrideDial(protected.Dial)
}

// StartResult provides information about the started Lantern
type StartResult struct {
	HTTPAddr   string
	SOCKS5Addr string
}

// Start starts a HTTP and SOCKS proxies at random addresses. It blocks up till
// the given timeout waiting for the proxy to listen, and returns the addresses
// at which it is listening (HTTP, SOCKS). If the proxy doesn't start within the
// given timeout, this method returns an error.
//
// If a Lantern proxy is already running within this process, that proxy is
// reused.
//
// Note - this does not wait for the entire initialization sequence to finish,
// just for the proxy to be listening. Once the proxy is listening, one can
// start to use it, even as it finishes its initialization sequence. However,
// initial activity may be slow, so clients with low read timeouts may
// time out.
func Start(configDir string, timeoutMillis int) (*StartResult, error) {
	startOnce.Do(func() {
		go run(configDir)
	})

	start := time.Now()
	addr, ok := client.Addr(time.Duration(timeoutMillis) * time.Millisecond)
	if !ok {
		return nil, fmt.Errorf("HTTP Proxy didn't start within given timeout")
	}
	elapsed := time.Now().Sub(start)

	socksAddr, ok := client.Socks5Addr((time.Duration(timeoutMillis) * time.Millisecond) - elapsed)
	if !ok {
		return nil, fmt.Errorf("SOCKS5 Proxy didn't start within given timeout")
	}
	return &StartResult{addr.(string), socksAddr.(string)}, nil
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
	flashlight.Run("localhost:0", // listen for HTTP on random address
		"localhost:0", // listen for SOCKS on random address
		configDir,     // place to store lantern configuration
		false,         // don't make config sticky
		func() bool { return true },                   // proxy all requests
		make(map[string]interface{}),                  // no special configuration flags
		func(cfg *config.Config) bool { return true }, // beforeStart()
		func(cfg *config.Config) {},                   // afterStart()
		func(cfg *config.Config) {},                   // onConfigUpdate
		func(err error) {},                            // onError
	)
}
