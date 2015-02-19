package ui

import (
	"fmt"
	"net"
	"net/http"
	"path"
	"path/filepath"
	"runtime"
	"sync"
	"time"

	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"
	"github.com/getlantern/tarfs"
	"github.com/gorilla/mux"
	"github.com/skratchdot/open-golang/open"
)

const (
	localResourcesPath = "../ui/app"
)

var (
	log = golog.LoggerFor("http")

	l      net.Listener
	r      *mux.Router
	fs     http.FileSystem
	server *http.Server
	uiaddr string
)

func Start(addr string) error {
	var err error
	l, err = net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("Unable to listen at %v: %v", addr, l)
	}

	log.Debugf("Creating tarfs filesystem that preferes local resources at %v", filepath.Abs(localResourcesPath))
	fs, err = tarfs.New(Resources, localResourcesPath)
	if err != nil {
		return fmt.Errorf("Unable to open tarfs filesystem: %v", err)
	}

	r = mux.NewRouter()
	r.Handle("/", http.FileServer(fs))

	server = &http.Server{
		Handler: r,
	}
	server.Handle("/")
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

func Open() {
	open.Run(uiaddr)
}
