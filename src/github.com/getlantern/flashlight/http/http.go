package http

import (
	"fmt"
	"net/http"
	"path"
	"runtime"
	"sync"
	"time"

	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
	"github.com/getlantern/proxiedsites"
	"github.com/getlantern/tarfs"
	"github.com/gorilla/websocket"
	"github.com/skratchdot/open-golang/open"
)

const (
	UIUrl = "http://%s"
	// Assume UI directory to be a sibling directory
	// of flashlight parent dir
	LocalUIDir = "../../../ui/app"
	// Determines the chunking size of messages used by gorilla
	MaxMessageSize = 1024
)

var (
	log      = golog.LoggerFor("http")
	upgrader = &websocket.Upgrader{ReadBufferSize: 1024, WriteBufferSize: MaxMessageSize}
	UIDir    string
	srv      *UIServer
	mutex    sync.Mutex
)

// represents a UI client
type Client struct {
	// UI websocket connection
	Conn *websocket.Conn

	// Buffered channel of proxied sites
	msg chan *proxiedsites.Config
}

type UIServer struct {
	connections map[*Client]bool // pool of UI client connections
	addr        string
	// current set of proxied sites
	proxiedSites *proxiedsites.ProxiedSites

	requests  chan *Client
	connClose chan *Client // handles client disconnects
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

// when websocket connection is first opened, we write
// proxied sites (global list + additions) - deletions
// the gorilla websocket module automatically
// chunks messages according to WriteBufferSize
func (srv UIServer) writeGlobalList(client *Client) {
	initMsg := proxiedsites.Config{
		Additions: srv.proxiedSites.GetEntries(),
	}
	// write the JSON encoding of the proxied sites to the
	// websocket connection
	if err := client.Conn.WriteJSON(initMsg); err != nil {
		log.Errorf("Error writing initial proxied sites: %s", err)
	}
}

func (srv UIServer) writeProxiedSites(client *Client) {
	defer client.Conn.Close()
	for {
		select {
		case msg, recv := <-client.msg:
			if !recv {
				// write empty message to close connection on error sending
				client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := client.Conn.WriteJSON(msg); err != nil {
				srv.connClose <- client
				log.Errorf("Error writing proxied sites to UI instance: %s", err)
				return
			}
		}
	}
}

// Reads a message from a UI client
func (srv UIServer) readClientMessage(client *Client) {
	defer func() {
		srv.connClose <- client
		client.Conn.Close()
	}()
	for {
		// Receive updated proxied sites configuration from client
		// Encoding it as JSON and synchronizing it with updates
		var updates proxiedsites.Config
		err := client.Conn.ReadJSON(&updates)
		if err != nil {
			break
		}
		srv.proxiedSites.Update(&updates)
		srv.proxiedSites.Updates <- srv.proxiedSites.GetConfig()
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
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Error(err)
		return
	}
	client := &Client{Conn: ws, msg: make(chan *proxiedsites.Config)}
	srv.requests <- client

	go srv.writeProxiedSites(client)
	srv.readClientMessage(client)
}

func (srv UIServer) processRequests() {
	for {
		select {
		case diff := <-srv.proxiedSites.CfgUpdates:
			// write proxied sites update to every UI instance
			for c := range srv.connections {
				select {
				// write the JSON encoding of the proxied sites changes
				// to the UI clients
				case c.msg <- diff:
				default:
					// close and remove unresponsive connections
					close(c.msg)
					delete(srv.connections, c)
				}
			}
		case c := <-srv.requests:
			log.Debug("New UI client connected..")
			srv.connections[c] = true
			// write initial proxied sites list
			srv.writeGlobalList(c)
		case c := <-srv.connClose:
			log.Debug("UI client disconnected..")
			if _, ok := srv.connections[c]; ok {
				delete(srv.connections, c)
				close(c.msg)
			}
		}
	}
}

func ConfigureUIServer(UIAddr string, openUI bool,
	proxiedSites *proxiedsites.ProxiedSites) {

	mutex.Lock()
	defer mutex.Unlock()

	if srv != nil {
		srv.proxiedSites = proxiedSites
		return
	}

	// initial request, connection close channels and
	// connection pool for this UI server
	srv = &UIServer{
		addr:         UIAddr,
		proxiedSites: proxiedSites,
		connClose:    make(chan *Client),
		requests:     make(chan *Client),
		connections:  make(map[*Client]bool),
	}

	go srv.processRequests()

	r := http.NewServeMux()
	r.Handle("/data", srv)
	r.HandleFunc("/proxy_on.pac", servePacFile)
	serveHome(r)

	log.Debugf("Starting UI HTTP server at %s", srv.addr)
	httpServer := &http.Server{
		Addr:    srv.addr,
		Handler: r,
	}

	// if the openui flag is specified, the UI is automatically
	// opened in the default browser on start
	OpenUI(openUI, UIAddr)

	// Run the UI websocket server asynchronously
	log.Fatal(httpServer.ListenAndServe())
}
