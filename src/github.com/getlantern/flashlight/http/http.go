package http

import (
	"fmt"
	"net/http"
	"path"
	"reflect"
	"runtime"
	"time"

	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"
	"github.com/getlantern/tarfs"
	"github.com/gorilla/websocket"
	"github.com/skratchdot/open-golang/open"
)

const (
	UIUrl      = "http://%s"
	LocalUIDir = "../../../ui/app"
)

var (
	log      = golog.LoggerFor("http")
	upgrader = &websocket.Upgrader{ReadBufferSize: 1024, WriteBufferSize: 1024}
	UIDir    string
)

type UIServer struct {
	Conn             *websocket.Conn
	ProxiedSites     *proxiedsites.ProxiedSites
	ProxiedSitesChan chan *proxiedsites.Config
	Addr             string
	ConfigUpdates    chan *config.Config
}

type ProxiedSitesMsg struct {
	Global  []string `json:"Global, omitempty"`
	Entries []string `json:"Entries, omitempty"`
}

// Assume the default directory containing UI assets is
// a sibling directory to the current directory
func init() {
	_, curDir, _, ok := runtime.Caller(1)
	if !ok {
		log.Errorf("Unable to determine current directory")
		return
	}
	UIDir = path.Join(curDir, LocalUIDir)
}

// returns the Proxy auto-config file
func servePacFile(w http.ResponseWriter, r *http.Request) {
	pacFile := proxiedsites.GetPacFile()
	http.ServeFile(w, r, pacFile)
}

func serveHome(r *http.ServeMux) {
	UIDirExists, err := util.DirExists(UIDir)
	if err != nil {
		log.Debugf("UI Directory does not exist %s", err)
	}

	if UIDirExists {
		// UI directory found--serve assets directly from it
		log.Debugf("Serving UI assets from directory %s", UIDir)
		r.Handle("/", http.FileServer(http.Dir(UIDir)))
	} else {
		start := time.Now()
		fs, err := tarfs.New(Resources, "../ui/app")
		if err != nil {
			panic(err)
		}
		delta := time.Now().Sub(start)
		log.Debugf("tarfs startup time: %v", delta)
		r.Handle("/", http.FileServer(fs))
	}
}

func (srv UIServer) writeProxiedSites() {
	for {
		msg := &ProxiedSitesMsg{
			Global:  srv.ProxiedSites.GetGlobalList(),
			Entries: srv.ProxiedSites.GetEntries(),
		}
		// write the JSON encoding of the proxied sites to the
		// websocket connection
		if err := srv.Conn.WriteJSON(msg); err != nil {
			log.Errorf("Error writing initial proxied sites: %s", err)
		}
		// wait for YAML config updates to write to the websocket again
		cfg := <-srv.ConfigUpdates
		log.Debugf("Proxied sites updated in config file; applying changes")
		srv.ProxiedSites = proxiedsites.New(cfg.Client.ProxiedSites)
		srv.ProxiedSites.RefreshEntries()
	}
}

func (srv UIServer) readClientMessage() {
	defer srv.Conn.Close()
	for {
		var str interface{}
		err := srv.Conn.ReadJSON(&str)
		log.Debug(str)
		if err != nil {
			break
		}
	}
}

// if the openui flag is specified, the UI is automatically
// opened in the default browser
func OpenUI(shouldOpen bool, uiAddr string) {

	uiAddr = fmt.Sprintf(UIUrl, uiAddr)

	if shouldOpen {
		err := open.Run(uiAddr)
		if err != nil {
			log.Errorf("Could not open UI! %s", err)
		}
	}
}

// handles websocket requests from the client
func (srv UIServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var err error
	if r.Method != "GET" {
		http.Error(w, "Method not allowed", 405)
		return
	}
	// Upgrade with a HTTP request returns a websocket connection
	srv.Conn, err = upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error(err)
		return
	}
	// write initial proxied sites list
	go srv.writeProxiedSites()
	srv.readClientMessage()
}

// poll for config updates to the proxiedsites
// with this immediately see flashlight.yaml
// changes in the UI
func (srv UIServer) ConfigureProxySites(cfg *config.Config) {
	if !reflect.DeepEqual(srv.ProxiedSites.GetConfig(), cfg.Client.ProxiedSites) {
		log.Debugf("proxiedsites changed in flashlight.yaml..")
		srv.ProxiedSites = proxiedsites.New(cfg.Client.ProxiedSites)
		srv.writeProxiedSites()
		srv.ProxiedSites.RefreshEntries()
	}
}

func (srv UIServer) StartServer() {

	r := http.NewServeMux()
	r.Handle("/data", srv)
	r.HandleFunc("/proxy_on.pac", servePacFile)
	serveHome(r)

	httpServer := &http.Server{
		Addr:    srv.Addr,
		Handler: r,
	}

	log.Debugf("Starting UI HTTP server at %s", srv.Addr)
	go log.Fatal(httpServer.ListenAndServe())
}
