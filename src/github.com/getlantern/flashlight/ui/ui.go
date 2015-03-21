package ui

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"
	"runtime"

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

	r = http.NewServeMux()
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

func Start(addr string) error {
	var err error
	l, err = net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("Unable to listen at %v: %v", addr, l)
	}

	r.Handle("/", http.FileServer(fs))

	server = &http.Server{
		Handler: r,
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

// Show opens the UI in a browser.
func Show() {
	open.Run(uiaddr)
}
