// Package lantern provides an embeddable client-side web proxy
package lantern

import (
	"compress/bzip2"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/getlantern/autoupdate"
	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight"
	"github.com/getlantern/flashlight/app"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/feed"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/protected"
	"github.com/getlantern/tlsdialer"
)

var (
	log = golog.LoggerFor("lantern")

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
	protected.Configure(protector.Protect, dnsServer)
	tlsdialer.OverrideResolve(protected.Resolve)
	tlsdialer.OverrideDial(protected.Dial)
}

// RemoveOverrides removes the protected tlsdialer overrides
// that allowed connections to bypass the VPN.
func RemoveOverrides() {
	tlsdialer.OverrideResolve(nil)
	tlsdialer.OverrideDial(nil)
}

// StartResult provides information about the started Lantern
type StartResult struct {
	HTTPAddr   string
	SOCKS5Addr string
}

type FeedProvider interface {
	AddSource(string)
}

type FeedRetriever interface {
	AddFeed(string, string, string, string)
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

//userConfig supplies user data for fetching user-specific configuration.
type userConfig struct {
}

func (uc *userConfig) GetToken() string {
	return ""
}

func (uc *userConfig) GetUserID() string {
	return "0"
}

func run(configDir string) {
	err := os.MkdirAll(configDir, 0755)
	if os.IsExist(err) {
		log.Errorf("Unable to create configDir at %v: %v", configDir, err)
		return
	}

	flashlight.Run("127.0.0.1:0", // listen for HTTP on random address
		"127.0.0.1:0", // listen for SOCKS on random address
		configDir,     // place to store lantern configuration
		false,         // don't make config sticky
		func() bool { return true },                   // proxy all requests
		make(map[string]interface{}),                  // no special configuration flags
		func(cfg *config.Config) bool { return true }, // beforeStart()
		func(cfg *config.Config) {},                   // onConfigUpdate
		func(cfg *config.Config) {},                   // onConfigUpdate
		&userConfig{},
		func(err error) {}, // onError
	)
}

func CheckForUpdates(proxyAddr, appVersion string) string {
	url, err := autoupdate.CheckMobileUpdate(proxyAddr, appVersion,
		"https://update-stage.getlantern.org/update",
		[]byte(app.PackagePublicKey))
	if err != nil {
		log.Errorf("Error trying to fetch update: %v", err)
		return ""
	}
	return url
}

type Updater interface {
	ShowProgress(string)
	DisplayError()
}

// passThru wraps an existing io.Reader.
type passThru struct {
	io.Reader
	Updater
	total    int64 // Total # of bytes transferred
	length   int64 // Expected length
	progress float64
}

// Read 'overrides' the underlying io.Reader's Read method.
// This is the one that will be called by io.Copy(). We simply
// use it to keep track of byte counts and then forward the call.
func (pt *passThru) Read(p []byte) (int, error) {
	n, err := pt.Reader.Read(p)
	if n > 0 {
		pt.total += int64(n)
		percentage := float64(pt.total) / float64(pt.length) * float64(100)
		i := int(percentage / float64(10))
		is := fmt.Sprintf("%v", i)
		pt.Updater.ShowProgress(fmt.Sprintf("%d", int(percentage)))

		if percentage-pt.progress > 2 {
			fmt.Fprintf(os.Stderr, is)
			pt.progress = percentage
		}
	}

	return n, err
}

func DownloadUpdate(proxyAddr, url, apkPath string, updater Updater) string {
	log.Debugf("Attempting to download APK from %s", url)

	var err error
	var req *http.Request
	var res *http.Response
	var httpClient *http.Client

	out, err := os.Create(apkPath)
	if err != nil {
		log.Errorf("Error creating APK path: %v", err)
		return ""
	}
	defer out.Close()

	if proxyAddr == "" {
		// if no proxyAddr is supplied, use an ordinary http client
		httpClient = &http.Client{}
	} else {
		httpClient, err = util.HTTPClient("", eventual.DefaultGetter(proxyAddr))
		if err != nil {
			log.Errorf("Error creating http client: %v", err)
			updater.DisplayError()
			return ""
		}
	}

	if req, err = http.NewRequest("GET", url, nil); err != nil {
		log.Errorf("Error downloading update: %v", err)
		updater.DisplayError()
		return ""
	}

	// ask for gzipped feed content
	req.Header.Add("Accept-Encoding", "gzip")

	if res, err = httpClient.Do(req); err != nil {
		log.Errorf("Error requesting update: %v", err)
		updater.DisplayError()
		return ""
	}

	defer res.Body.Close()

	bzip2Reader := bzip2.NewReader(res.Body)

	readerpt := &passThru{Updater: updater, Reader: bzip2Reader, length: res.ContentLength}

	/*contents, err := ioutil.ReadAll(readerpt)
	if err != nil {
		log.Errorf("Error downloading update: %v", err)
		updater.DisplayError()
		return
	}*/

	_, err = io.Copy(out, readerpt)
	if err != nil {
		log.Errorf("Error copying update: %v", err)
		return ""
	}

	return apkPath
}

// GetFeed fetches the public feed thats displayed on Lantern's main screen
func GetFeed(locale string, allStr string, proxyAddr string,
	provider FeedProvider) {
	feed.GetFeed(locale, allStr, proxyAddr, provider)
}

// FeedByName grabs the feed results for a given feed source name
func FeedByName(name string, retriever FeedRetriever) {
	feed.FeedByName(name, retriever)
}
