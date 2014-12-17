package statserver

import (
	"encoding/json"
	"net/http"
	"sync"

	"github.com/getlantern/eventsource"
	"github.com/getlantern/flashlight/log"
)

// Server provides an SSE server that publishes stat updates for peers.
// See (http://www.html5rocks.com/en/tutorials/eventsource/basics/) for more
// about Server-Sent Events
type Server struct {
	Addr         string
	clients      map[int]*Client
	clientsMutex sync.RWMutex
	clientIdSeq  int
	peers        map[string]*Peer
	peersMutex   sync.Mutex
}

// Client represents a client connected to the Server
type Client struct {
	id      int
	conn    *eventsource.Conn
	server  *Server
	updates chan []byte
}

type Update struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

func (server *Server) ListenAndServe() error {
	server.clients = make(map[int]*Client)
	server.peers = make(map[string]*Peer)
	httpServer := &http.Server{
		Addr:    server.Addr,
		Handler: eventsource.Handler(server.onNewClient),
	}
	return httpServer.ListenAndServe()
}

func (server *Server) addClient(conn *eventsource.Conn) *Client {
	server.clientsMutex.Lock()
	defer server.clientsMutex.Unlock()
	id := server.clientIdSeq
	server.clientIdSeq = server.clientIdSeq + 1
	client := &Client{
		id:      id,
		conn:    conn,
		server:  server,
		updates: make(chan []byte, 1000),
	}
	server.clients[id] = client
	return client
}

func (server *Server) removeClient(id int) {
	server.clientsMutex.Lock()
	defer server.clientsMutex.Unlock()
	delete(server.clients, id)
}

func (server *Server) onNewClient(conn *eventsource.Conn) {
	client := server.addClient(conn)
	for {
		select {
		case update := <-client.updates:
			client.conn.Write(update)
		case <-client.conn.CloseNotify():
			client.server.removeClient(client.id)
		}
	}
}

func (server *Server) OnBytesReceived(ip string, bytes int64) {
	peer, err := server.getOrCreatePeer(ip)
	if err != nil {
		log.Errorf("Unable to getOrCreatePeer: %s", err)
		return
	}
	peer.onBytesReceived(bytes)
}

func (server *Server) OnBytesSent(ip string, bytes int64) {
	peer, err := server.getOrCreatePeer(ip)
	if err != nil {
		log.Errorf("Unable to getOrCreatePeer: %s", err)
		return
	}
	peer.onBytesSent(bytes)
}

func (server *Server) getOrCreatePeer(ip string) (*Peer, error) {
	server.peersMutex.Lock()
	defer server.peersMutex.Unlock()
	peer, found := server.peers[ip]
	if found {
		return peer, nil
	}
	peer, err := newPeer(ip, server.onPeerUpdate)
	if err != nil {
		return nil, err
	}
	server.peers[ip] = peer
	return peer, nil
}

func (server *Server) onPeerUpdate(peer *Peer) {
	update, err := json.Marshal(&Update{
		Type: "peer",
		Data: peer,
	})
	if err != nil {
		log.Errorf("Unable to marshal peer update: %s", err)
		return
	}
	server.pushUpdate(update)
}

func (server *Server) pushUpdate(update []byte) {
	server.clientsMutex.Lock()
	defer server.clientsMutex.Unlock()
	for _, client := range server.clients {
		client.updates <- update
	}
}
