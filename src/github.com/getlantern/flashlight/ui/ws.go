package ui

import (
	"io"
	"net/http"
	"path"
	"sync"

	"github.com/gorilla/websocket"
)

const (
	// Determines the chunking size of messages used by gorilla
	MaxMessageSize = 1024
)

var (
	upgrader = &websocket.Upgrader{ReadBufferSize: 1024, WriteBufferSize: MaxMessageSize}
)

// UIChannel represents a data channel to/from the UI. UIChannel will have one
// underlying websocket connection for each connected browser window. All
// messages from any browser window are available via In and all messages sent
// to Out will be published to all browser windows.
type UIChannel struct {
	URL string
	In  <-chan []byte
	Out chan<- []byte

	in     chan []byte
	out    chan []byte
	nextId int
	conns  map[int]*wsconn
	m      sync.Mutex
}

type ConnectFunc func(write func([]byte) error) error

// NewChannel establishes a new channel to the UI at the given path. When the UI
// connects to this path, we will establish a websocket to the UI to carry
// messages for this UIChannel. The given onConnect function is called anytime
// that the UI connects.
func NewChannel(p string, onConnect ConnectFunc) *UIChannel {
	c := newUIChannel(path.Join(uiaddr, p))

	r.HandleFunc(p, func(resp http.ResponseWriter, req *http.Request) {
		log.Tracef("Got connection to %v", c.URL)
		var err error

		if req.Method != "GET" {
			http.Error(resp, "Method not allowed", 405)
			return
		}
		// Upgrade with a HTTP request returns a websocket connection
		ws, err := upgrader.Upgrade(resp, req, nil)
		if err != nil {
			log.Errorf("Unable to upgrade %v to websocket: %v", p, err)
			return
		}

		log.Tracef("Upgraded to websocket at %v", c.URL)
		c.m.Lock()
		if onConnect != nil {
			err = onConnect(func(b []byte) error {
				log.Tracef("Writing initial message: %q", b)
				return ws.WriteMessage(websocket.TextMessage, b)
			})
			if err != nil {
				log.Errorf("Error processing onConnect, disconnecting websocket: %v", err)
				ws.Close()
				c.m.Unlock()
				return
			}
		}
		c.nextId += 1
		conn := &wsconn{
			id: c.nextId,
			c:  c,
			ws: ws,
		}
		c.conns[conn.id] = conn
		c.m.Unlock()
		log.Tracef("About to read from connection to %v", c.URL)
		conn.read()
	})

	return c
}

func newUIChannel(url string) *UIChannel {
	in := make(chan []byte, 100)
	out := make(chan []byte)

	c := &UIChannel{
		URL:    url,
		In:     in,
		in:     in,
		Out:    out,
		out:    out,
		nextId: 0,
		conns:  make(map[int]*wsconn),
	}

	go c.write()
	return c
}

func (c *UIChannel) write() {
	defer func() {
		log.Tracef("Closing all websockets to %v", c.URL)
		c.m.Lock()
		for _, conn := range c.conns {
			conn.ws.Close()
		}
		c.m.Unlock()
	}()

	for msg := range c.out {
		c.m.Lock()
		for _, conn := range c.conns {
			err := conn.ws.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				log.Debugf("Error writing to UI: %v", err)
				delete(c.conns, conn.id)
			}
		}
		c.m.Unlock()
	}
}

func (c *UIChannel) Close() {
	close(c.out)
}

// wsconn ties a websocket.Conn to a UIChannel
type wsconn struct {
	id int
	c  *UIChannel
	ws *websocket.Conn
}

func (c *wsconn) read() {
	for {
		_, b, err := c.ws.ReadMessage()
		if err != nil {
			if err != io.EOF {
				log.Debugf("Error reading from UI: %v", err)
			}
			return
		}
		c.c.in <- b
	}
}

// // when websocket connection is first opened, we write
// // proxied sites (global list + additions) - deletions
// // the gorilla websocket module automatically
// // chunks messages according to WriteBufferSize
// func (srv UIServer) writeGlobalList(client *Client) {
// 	initMsg := proxiedsites.Config{
// 		Additions: srv.proxiedSites.GetEntries(),
// 	}
// 	// write the JSON encoding of the proxied sites to the
// 	// websocket connection
// 	if err := client.Conn.WriteJSON(initMsg); err != nil {
// 		log.Errorf("Error writing initial proxied sites: %s", err)
// 	}
// }

// func (srv UIServer) writeProxiedSites(client *Client) {
// 	defer client.Conn.Close()
// 	for {
// 		select {
// 		case msg, recv := <-client.msg:
// 			if !recv {
// 				// write empty message to close connection on error sending
// 				client.Conn.WriteMessage(websocket.CloseMessage, []byte{})
// 				return
// 			}
// 			if err := client.Conn.WriteJSON(msg); err != nil {
// 				srv.connClose <- client
// 				log.Errorf("Error writing proxied sites to UI instance: %s", err)
// 				return
// 			}
// 		}
// 	}
// }

// // Reads a message from a UI client
// func (srv UIServer) readClientMessage(client *Client) {
// 	defer func() {
// 		srv.connClose <- client
// 		client.Conn.Close()
// 	}()
// 	for {
// 		// Receive updated proxied sites configuration from client
// 		// Encoding it as JSON and synchronizing it with updates
// 		var updates proxiedsites.Config
// 		err := client.Conn.ReadJSON(&updates)
// 		if err != nil {
// 			break
// 		}
// 		srv.proxiedSites.Update(&updates)
// 		srv.proxiedSites.Updates <- srv.proxiedSites.GetConfig()
// 	}
// }

// // if the openui flag is specified, the UI is automatically
// // opened in the default browser
// func OpenUI(shouldOpen bool, uiAddr string) {
// 	uiAddr = fmt.Sprintf(UIUrl, uiAddr)
// 	if shouldOpen {
// 		err := open.Run(uiAddr)
// 		if err != nil {
// 			log.Errorf("Could not open UI! %s", err)
// 		}
// 	}
// }

// // handles websocket requests from the client
// func (srv UIServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
// 	var err error

// 	if r.Method != "GET" {
// 		http.Error(w, "Method not allowed", 405)
// 		return
// 	}
// 	// Upgrade with a HTTP request returns a websocket connection
// 	ws, err := upgrader.Upgrade(w, r, nil)
// 	if err != nil {
// 		log.Error(err)
// 		return
// 	}
// 	client := &Client{Conn: ws, msg: make(chan *proxiedsites.Config)}
// 	srv.requests <- client

// 	go srv.writeProxiedSites(client)
// 	srv.readClientMessage(client)
// }

// func (srv UIServer) processRequests() {
// 	for {
// 		select {
// 		case diff := <-srv.proxiedSites.CfgUpdates:
// 			// write proxied sites update to every UI instance
// 			for c := range srv.connections {
// 				select {
// 				// write the JSON encoding of the proxied sites changes
// 				// to the UI clients
// 				case c.msg <- diff:
// 				default:
// 					// close and remove unresponsive connections
// 					close(c.msg)
// 					delete(srv.connections, c)
// 				}
// 			}
// 		case c := <-srv.requests:
// 			log.Debug("New UI client connected..")
// 			srv.connections[c] = true
// 			// write initial proxied sites list
// 			srv.writeGlobalList(c)
// 		case c := <-srv.connClose:
// 			log.Debug("UI client disconnected..")
// 			if _, ok := srv.connections[c]; ok {
// 				delete(srv.connections, c)
// 				close(c.msg)
// 			}
// 		}
// 	}
// }

// func ConfigureUIServer(UIAddr string, openUI bool,
// 	proxiedSites *proxiedsites.ProxiedSites) {

// 	mutex.Lock()
// 	defer mutex.Unlock()

// 	if srv != nil {
// 		srv.proxiedSites = proxiedSites
// 		return
// 	}

// 	// initial request, connection close channels and
// 	// connection pool for this UI server
// 	srv = &UIServer{
// 		addr:         UIAddr,
// 		proxiedSites: proxiedSites,
// 		connClose:    make(chan *Client),
// 		requests:     make(chan *Client),
// 		connections:  make(map[*Client]bool),
// 	}

// 	go srv.processRequests()

// 	r := http.NewServeMux()
// 	r.Handle("/data", srv)
// 	r.HandleFunc("/proxy_on.pac", servePacFile)
// 	serveHome(r)

// 	log.Debugf("Starting UI HTTP server at %s", srv.addr)
// 	httpServer := &http.Server{
// 		Addr:    srv.addr,
// 		Handler: r,
// 	}

// 	// if the openui flag is specified, the UI is automatically
// 	// opened in the default browser on start
// 	OpenUI(openUI, UIAddr)

// 	// Run the UI websocket server asynchronously
// 	log.Fatal(httpServer.ListenAndServe())
// }
