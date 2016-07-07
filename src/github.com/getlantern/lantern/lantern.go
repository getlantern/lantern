// Package lantern provides an embeddable client-side web proxy
package lantern

import (
	"encoding/base64"
	"fmt"
	"os"
	"strconv"
	"sync"
	"time"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/appdir"
	"github.com/getlantern/autoupdate"
	"github.com/getlantern/bandwidth"
	"github.com/getlantern/flashlight"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/feed"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/golog"
	"github.com/getlantern/netx"
	"github.com/getlantern/protected"
)

var (
	log = golog.LoggerFor("lantern")

	// compileTimePackageVersion is set at compile-time for production builds
	compileTimePackageVersion string

	// if true, run Lantern against our staging infrastructure
	stagingMode = "false"

	startOnce sync.Once
)

// SocketProtector is an interface for classes that can protect Android sockets,
// meaning those sockets will not be passed through the VPN.
type SocketProtector interface {
	Protect(fileDescriptor int) error
}

// ProtectConnections allows connections made by Lantern to be protected from
// routing via a VPN. This is useful when running Lantern as a VPN on Android,
// because it keeps Lantern's own connections from being captured by the VPN and
// resulting in an infinite loop.
func ProtectConnections(dnsServer string, protector SocketProtector) {
	p := protected.New(protector.Protect, dnsServer)
	netx.OverrideDial(p.Dial)
	netx.OverrideResolve(p.Resolve)
}

// RemoveOverrides removes the protected tlsdialer overrides
// that allowed connections to bypass the VPN.
func RemoveOverrides() {
	netx.Reset()
}

// StartResult provides information about the started Lantern
type StartResult struct {
	HTTPAddr   string
	SOCKS5Addr string
}

type UserConfig interface {
	AfterStart()
	BandwidthUpdate(int, int)
}

type FeedProvider feed.FeedProvider
type FeedRetriever feed.FeedRetriever
type Updater autoupdate.Updater

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
func Start(configDir string, timeoutMillis int, user UserConfig) (*StartResult, error) {

	appdir.SetHomeDir(configDir)

	startOnce.Do(func() {
		go run(configDir, user)
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

//userConfig supplies user data for fetching user-specific configuration.
type userConfig struct {
}

func (uc *userConfig) GetToken() string {
	return ""
}

func (uc *userConfig) GetUserID() int64 {
	return 0
}

func run(configDir string, user UserConfig) {
	flags := make(map[string]interface{})
	flags["staging"] = false

	err := os.MkdirAll(configDir, 0755)
	if os.IsExist(err) {
		log.Errorf("Unable to create configDir at %v: %v", configDir, err)
		return
	}

	if err := logging.EnableFileLogging(configDir); err != nil {
		log.Errorf("Unable to enable file logging: %v", err)
		return
	}
	log.Debugf("Writing log messages to %s/lantern.log", configDir)

	staging, err := strconv.ParseBool(stagingMode)
	if err == nil {
		flags["staging"] = staging
	} else {
		log.Errorf("Error parsing boolean flag: %v", err)
	}

	flashlight.Run("127.0.0.1:0", // listen for HTTP on random address
		"127.0.0.1:0", // listen for SOCKS on random address
		configDir,     // place to store lantern configuration
		false,         // don't make config sticky
		func() bool { return true }, // proxy all requests
		flags,
		func(cfg *config.Config) bool {
			beforeStart(cfg, user)
			return true
		},
		func(cfg *config.Config) {
			afterStart(cfg, user)
		},
		func(cfg *config.Config) {}, // onConfigUpdate
		&userConfig{},
		func(err error) {}, // onError
		base64.StdEncoding.EncodeToString(uuid.NodeID()),
	)
}

func beforeStart(cfg *config.Config, user UserConfig) {
	go func() {
		for quota := range bandwidth.Updates {

			remaining := 0
			percent := 100
			if quota == nil {
				continue
			}

			allowed := quota.MiBAllowed
			if allowed < 0 || allowed > 50000000 {
				continue
			}

			if quota.MiBUsed >= quota.MiBAllowed {
				percent = 100
				remaining = 0
			} else {
				percent = int(100 * (float64(quota.MiBUsed) / float64(quota.MiBAllowed)))
				remaining = int(quota.MiBAllowed - quota.MiBUsed)
			}

			user.BandwidthUpdate(percent, remaining)
		}
	}()
}

func afterStart(cfg *config.Config, user UserConfig) {
	user.AfterStart()
}

// CheckForUpdates checks to see if a new version of Lantern is available
func CheckForUpdates(shouldProxy bool) (string, error) {
	updateServer := config.DefaultUpdateServerURL
	if stagingMode == "true" {
		updateServer = "http://update-stage.getlantern.org/"
	}

	return autoupdate.CheckMobileUpdate(shouldProxy, updateServer,
		compileTimePackageVersion)
}

// DownloadUpdate downloads the latest APK from the given url to the apkPath
// file destination.
func DownloadUpdate(url, apkPath string, shouldProxy bool, updater Updater) {
	autoupdate.UpdateMobile(shouldProxy, url, apkPath, updater)
}

func GetFeed(locale string, allStr string, shouldProxy bool, provider FeedProvider) {
	feed.GetFeed(locale, allStr, shouldProxy, provider)
}

// FeedByName grabs the feed results for a given feed source name
func FeedByName(name string, retriever FeedRetriever) {
	feed.FeedByName(name, retriever)
}
