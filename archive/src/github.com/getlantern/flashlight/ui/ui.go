package ui

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/edgedetect"
	"github.com/getlantern/golog"
	"github.com/getlantern/tarfs"
	"github.com/skratchdot/open-golang/open"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/feed"
)

const (
	LocalUIDir = "../../../../../../lantern-ui/app"
)

var (
	log = golog.LoggerFor("flashlight.ui")

	l               net.Listener
	fs              *tarfs.FileSystem
	Translations    *tarfs.FileSystem
	server          *http.Server
	uiaddr          string
	proxiedUIAddr   string
	preferProxiedUI int32

	openedExternal = false
	externalUrl    string
	r              = http.NewServeMux()
)

func init() {
	// Assume the default directory containing UI assets is
	// a sibling directory to this file's directory.
	localResourcesPath := ""
	_, curDir, _, ok := runtime.Caller(1)
	if !ok {
		log.Errorf("Unable to determine caller directory")
	} else {
		localResourcesPath = filepath.Join(curDir, LocalUIDir)
		absLocalResourcesPath, err := filepath.Abs(localResourcesPath)
		if err != nil {
			absLocalResourcesPath = localResourcesPath
		}
		log.Debugf("Creating tarfs filesystem that prefers local resources at %v", absLocalResourcesPath)
	}

	var err error
	fs, err = tarfs.New(Resources, localResourcesPath)
	if err != nil {
		// Panicking here because this shouldn't happen at runtime unless the
		// resources were incorrectly embedded.
		panic(fmt.Errorf("Unable to open tarfs filesystem: %v", err))
	}
	Translations = fs.SubDir("locale")
}

func Handle(p string, handler http.Handler) string {
	r.Handle(p, handler)
	return uiaddr + p
}

func Start(requestedAddr string, allowRemote bool, extUrl string) (string, error) {
	addr, err := net.ResolveTCPAddr("tcp4", requestedAddr)
	if err != nil {
		return "", fmt.Errorf("Unable to resolve UI address: %v", err)
	}

	// initProServer("127.0.0.1:1233") // Experimental server.

	externalUrl = extUrl
	if allowRemote {
		// If we want to allow remote connections, we have to bind all interfaces
		addr = &net.TCPAddr{Port: addr.Port}
	}
	if l, err = net.ListenTCP("tcp4", addr); err != nil {
		return "", fmt.Errorf("Unable to listen at %v: %v. Error is: %v", addr, l, err)
	}

	// This allows a second Lantern running on the system to trigger the existing
	// Lantern to show the UI, or at least try to
	handler := func(resp http.ResponseWriter, req *http.Request) {
		// If we're allowing remote, we're in practice not showing the UI on this
		// typically headless system, so don't allow triggering of the UI.
		if !allowRemote {
			Show()
		}
		resp.WriteHeader(http.StatusOK)
	}

	// We use the backend to detect the user's country and redirect the browser
	// to the correct URL that will itself be proxied over Lantern.
	feedHandler := func(resp http.ResponseWriter, req *http.Request) {
		vals := req.URL.Query()
		defaultLang := vals.Get("lang")
		url := feed.GetFeedURL(defaultLang)
		http.Redirect(resp, req, url, http.StatusFound)
	}

	r.Handle("/startup", http.HandlerFunc(handler))
	r.Handle("/feed", http.HandlerFunc(feedHandler))
	r.Handle("/", http.FileServer(fs))

	server = &http.Server{
		Handler:  r,
		ErrorLog: log.AsStdLogger(),
	}
	go func() {
		err := server.Serve(l)
		if err != nil {
			log.Errorf("Error serving: %v", err)
		}
	}()
	uiaddr = fmt.Sprintf("http://%v", l.Addr().String())

	// Note - we display the UI using the LanternSpecialDomain. This is necessary
	// for Microsoft Edge on Windows 10 because, being a Windows Modern App, its
	// default network isolation settings prevent it from opening websites on the
	// loopback address. We get around this by exploiting the fact that Edge will
	// happily connect to our proxy server running on the loopback interface. So,
	// we use what looks like a real domain for the UI (ui.lantern.io), the proxy
	// detects this and reroutes the traffic to the local UI server. The proxy is
	// allowed to connect to loopback because it doesn't have the same restriction
	// as Microsoft Edge.
	proxiedUIAddr = fmt.Sprintf("http://%v", client.LanternSpecialDomain)
	log.Debugf("UI available at %v", uiaddr)

	return l.Addr().String(), nil
}

func PreferProxiedUI(val bool) (newAddr string, addrChanged bool) {
	previousPreferredUIAddr := getPreferredUIAddr()
	updated := int32(0)
	if val {
		updated = 1
	}
	atomic.StoreInt32(&preferProxiedUI, updated)
	newPreferredUIAddr := getPreferredUIAddr()
	return newPreferredUIAddr, newPreferredUIAddr != previousPreferredUIAddr
}

func shouldPreferProxiedUI() bool {
	return atomic.LoadInt32(&preferProxiedUI) == 1
}

func getPreferredUIAddr() string {
	// We only use the proxied UI address if the default browser is Microsoft Edge
	if edgedetect.DefaultBrowserIsEdge() && shouldPreferProxiedUI() {
		return proxiedUIAddr
	} else {
		return uiaddr
	}
}

// Show opens the UI in a browser. Note we know the UI server is
// *listening* at this point as long as Start is correctly called prior
// to this method. It may not be reading yet, but since we're the only
// ones reading from those incoming sockets the fact that reading starts
// asynchronously is not a problem.
func Show() {
	go func() {
		addr := getPreferredUIAddr()
		err := open.Run(addr)
		if err != nil {
			log.Errorf("Error opening page to `%v`: %v", addr, err)
		}

		onceBody := func() {
			openExternalUrl(externalUrl)
		}
		var run sync.Once
		run.Do(onceBody)
	}()
}

// openExternalUrl opens an external URL of one of our partners automatically
// at startup if configured to do so. It should only open the first time in
// a given session that Lantern is opened.
func openExternalUrl(u string) {
	var url string
	if u == "" {
		return
	} else if strings.HasPrefix(u, "https://www.manoto1.com/") || strings.HasPrefix(u, "https://www.facebook.com/manototv") {
		// Here we make sure to override any old manoto URLs with the latest.
		url = "https://www.manototv.com/iran?utm_campaign=manotolantern"
	} else {
		url = u
	}
	time.Sleep(4 * time.Second)
	err := open.Run(url)
	if err != nil {
		log.Errorf("Error opening external page to `%v`: %v", uiaddr, err)
	}
}
