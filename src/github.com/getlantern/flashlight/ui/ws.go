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
	upgrader = &websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: MaxMessageSize,
		// CheckOrigin:     func(r *http.Request) bool { return true }, // I need this to test Lantern UI from a different host.
	}
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
				if err := ws.Close(); err != nil {
					log.Debugf("Error closing WebSockets connection: %s", err)
				}
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
			if err := conn.ws.Close(); err != nil {
				log.Debugf("Error closing WebSockets connection", err)
			}
			delete(c.conns, conn.id)
		}
		c.m.Unlock()
	}()

	for msg := range c.out {
		c.m.Lock()
		for _, conn := range c.conns {
			err := conn.ws.WriteMessage(websocket.TextMessage, msg)
			if err != nil {
				log.Debugf("Error writing to UI %v for: %v", err, c.URL)
				delete(c.conns, conn.id)
			}
		}
		c.m.Unlock()
	}
}

func (c *UIChannel) Close() {
	log.Tracef("Closing channel")
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
		log.Tracef("Read message: %q", b)
		if err != nil {
			if err != io.EOF {
				log.Debugf("Error reading from UI: %v", err)
			}
			if err := c.ws.Close(); err != nil {
				log.Debugf("Error closing WebSockets connection", err)
			}
			return
		}
		log.Tracef("Sending to channel...")
		c.c.in <- b
	}
}
