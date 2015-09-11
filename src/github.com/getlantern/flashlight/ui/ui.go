package ui

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/tarfs"
	"github.com/skratchdot/open-golang/open"
)

const (
	LocalUIDir = "../../../lantern-ui/app"
)

var (
	log = golog.LoggerFor("flashlight.ui")

	l            net.Listener
	fs           *tarfs.FileSystem
	Translations *tarfs.FileSystem
	server       *http.Server
	uiaddr       string

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

func Start(tcpAddr *net.TCPAddr, allowRemote bool, extUrl string) (err error) {
	addr := tcpAddr
	externalUrl = extUrl
	if allowRemote {
		// If we want to allow remote connections, we have to bind all interfaces
		addr = &net.TCPAddr{Port: tcpAddr.Port}
	}
	if l, err = net.ListenTCP("tcp4", addr); err != nil {
		return fmt.Errorf("Unable to listen at %v: %v. Error is: %v", addr, l, err)
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
	r.Handle("/startup", http.HandlerFunc(handler))
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
	log.Debugf("UI available at %v", uiaddr)

	return nil
}

// Show opens the UI in a browser. Note we know the UI server is
// *listening* at this point as long as Start is correctly called prior
// to this method. It may not be reading yet, but since we're the only
// ones reading from those incoming sockets the fact that reading starts
// asynchronously is not a problem.
func Show() {
	go func() {
		err := open.Run(uiaddr)
		if err != nil {
			log.Errorf("Error opening page to `%v`: %v", uiaddr, err)
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
	} else if strings.HasPrefix(u, "https://www.facebook.com/manototv") {
		// Here we make sure to override any old manoto URLs with the latest.
		url = "https://www.facebook.com/manototv/app_128953167177144"
	} else {
		url = u
	}
	time.Sleep(4 * time.Second)
	err := open.Run(url)
	if err != nil {
		log.Errorf("Error opening external page to `%v`: %v", uiaddr, err)
	}
}
