package ui

import (
	"fmt"
	"net"
	"net/http"
	"path/filepath"

	"github.com/getlantern/golog"
	"github.com/getlantern/tarfs"
	"github.com/gorilla/mux"
	"github.com/skratchdot/open-golang/open"
)

const (
	localResourcesPath = "../ui/app"
)

var (
	log = golog.LoggerFor("ui")

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

	absLocalResourcesPath, err := filepath.Abs(localResourcesPath)
	if err != nil {
		absLocalResourcesPath = localResourcesPath
	}
	log.Debugf("Creating tarfs filesystem that prefers local resources at %v", absLocalResourcesPath)
	fs, err = tarfs.New(Resources, localResourcesPath)
	if err != nil {
		return fmt.Errorf("Unable to open tarfs filesystem: %v", err)
	}

	r = mux.NewRouter()
	// r.Handle("/", )

	server = &http.Server{
		Handler: http.FileServer(fs),
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

func Open() {
	open.Run(uiaddr)
}
