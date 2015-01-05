package statserver

import (
	"encoding/json"
	"net"
	"net/http"
	"sync"

	"github.com/getlantern/eventsource"
	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("flashlight.statserver")

	instance      *server
	instanceMutex sync.Mutex
)

func Start(addr string) {
	instanceMutex.Lock()
	defer instanceMutex.Unlock()
	if instance != nil {
		if instance.addr == addr {
			log.Debugf("Already started at %v, ignoring additional Start() call", instance.addr)
			return
		}
		defer instance.stop()
	}
	i := &server{
		addr: addr,
	}
	instance = i
	go i.listenAndServe()
}

func Stop() {
	instanceMutex.Lock()
	defer instanceMutex.Unlock()
	if instance != nil {
		instance.stop()
		instance = nil
	}
}

func OnBytesReceived(ip string, bytes int64) {
	instanceMutex.Lock()
	defer instanceMutex.Unlock()
	if instance != nil {
		instance.onBytesReceived(ip, bytes)
	}
}

func OnBytesSent(ip string, bytes int64) {
	instanceMutex.Lock()
	defer instanceMutex.Unlock()
	if instance != nil {
		instance.onBytesSent(ip, bytes)
	}
}

// server provides an SSE server that publishes stat updates for peers.
// See (http://www.html5rocks.com/en/tutorials/eventsource/basics/) for more
// about Server-Sent Events.
type server struct {
	addr         string
	l            net.Listener
	clients      map[int]*client
	clientsMutex sync.RWMutex
	clientIdSeq  int
	peers        map[string]*Peer
	peersMutex   sync.Mutex
}

// client represents a client connected to the Server
type client struct {
	id      int
	conn    *eventsource.Conn
	server  *server
	updates chan []byte
}

type update struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

func (s *server) listenAndServe() {
	log.Debugf("Starting at %v", s.addr)
	var err error
	s.l, err = net.Listen("tcp", s.addr)
	if err != nil {
		log.Errorf("Unable to listen at %v: %v", s.addr, err)
		return
	}
	s.clients = make(map[int]*client)
	s.peers = make(map[string]*Peer)
	httpServer := &http.Server{
		Addr:    s.addr,
		Handler: eventsource.Handler(s.onNewClient),
	}
	httpServer.Serve(s.l)
}

func (s *server) stop() error {
	log.Debugf("Stopping at %v", s.addr)
	return s.l.Close()
}

func (s *server) addClient(conn *eventsource.Conn) *client {
	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()
	id := s.clientIdSeq
	s.clientIdSeq = s.clientIdSeq + 1
	client := &client{
		id:      id,
		conn:    conn,
		server:  s,
		updates: make(chan []byte, 1000),
	}
	s.clients[id] = client
	return client
}

func (s *server) removeClient(id int) {
	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()
	delete(s.clients, id)
}

func (s *server) onNewClient(conn *eventsource.Conn) {
	client := s.addClient(conn)
	for {
		select {
		case update := <-client.updates:
			client.conn.Write(update)
		case <-client.conn.CloseNotify():
			client.server.removeClient(client.id)
		}
	}
}

func (s *server) onBytesReceived(ip string, bytes int64) {
	peer, err := s.getOrCreatePeer(ip)
	if err != nil {
		log.Errorf("Unable to getOrCreatePeer: %v", err)
		return
	}
	peer.onBytesReceived(bytes)
}

func (s *server) onBytesSent(ip string, bytes int64) {
	peer, err := s.getOrCreatePeer(ip)
	if err != nil {
		log.Errorf("Unable to getOrCreatePeer: %v", err)
		return
	}
	peer.onBytesSent(bytes)
}

func (s *server) getOrCreatePeer(ip string) (*Peer, error) {
	s.peersMutex.Lock()
	defer s.peersMutex.Unlock()
	peer, found := s.peers[ip]
	if found {
		return peer, nil
	}
	peer, err := newPeer(ip, s.onPeerUpdate)
	if err != nil {
		return nil, err
	}
	s.peers[ip] = peer
	return peer, nil
}

func (s *server) onPeerUpdate(peer *Peer) {
	update, err := json.Marshal(&update{
		Type: "peer",
		Data: peer,
	})
	if err != nil {
		log.Errorf("Unable to marshal peer update: %v", err)
		return
	}
	s.pushUpdate(update)
}

func (s *server) pushUpdate(update []byte) {
	s.clientsMutex.Lock()
	defer s.clientsMutex.Unlock()
	for _, client := range s.clients {
		client.updates <- update
	}
}
