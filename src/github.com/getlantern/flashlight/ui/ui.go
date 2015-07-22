package ui

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"
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

	externalUrl    = "NO_URL" // this string is going to be changed by Makefile
	openedExternal = false
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

func Start(tcpAddr *net.TCPAddr, allowRemote bool) (err error) {
	addr := tcpAddr
	if allowRemote {
		// If we want to allow remote connections, we have to bind all interfaces
		addr = &net.TCPAddr{Port: tcpAddr.Port}
	}
	if l, err = net.ListenTCP("tcp4", addr); err != nil {
		return fmt.Errorf("Unable to listen at %v: %v", addr, l)
	}

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
		if externalUrl != "NO"+"_URL" && !openedExternal {
			time.Sleep(4 * time.Second)
			err = open.Run(externalUrl)
			if err != nil {
				log.Errorf("Error opening external page to `%v`: %v", uiaddr, err)
			}
			openedExternal = true
		}
	}()
}
