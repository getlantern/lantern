package waddell

import (
	"net"
	"sync"
)

// ClientMgr provides a mechanism for managing connections to multiple waddell
// servers.
type ClientMgr struct {
	// Dial is a function that dials the waddell server at the given addr.
	Dial func(addr string) (net.Conn, error)

	// ServerCert: PEM-encoded certificate by which to authenticate the waddell
	// server. If provided, connection to waddell is encrypted with TLS. If not,
	// connection will be made plain-text.
	ServerCert string

	// ReconnectAttempts specifies how many consecutive times to try
	// reconnecting in the event of a connection failure. See
	// Client.ReconnectAttempts for more information.
	ReconnectAttempts int

	// OnId allows optionally registering a callback to be notified whenever a
	// PeerId is assigned to the client connected to the indicated addr (i.e. on
	// each successful connection to the waddell server at addr).
	OnId func(addr string, id PeerId)

	clients      map[string]*Client
	clientsMutex sync.Mutex
}

// ClientTo obtains the one (and only) client to the given addr, creating a new
// one if necessary. This method is safe to call from multiple goroutines.
func (m *ClientMgr) ClientTo(addr string) (*Client, error) {
	m.clientsMutex.Lock()
	defer m.clientsMutex.Unlock()
	if m.clients == nil {
		m.clients = make(map[string]*Client)
	}
	client := m.clients[addr]
	var err error
	if client == nil {
		cfg := &ClientConfig{
			Dial: func() (net.Conn, error) {
				return m.Dial(addr)
			},
			ServerCert:        m.ServerCert,
			ReconnectAttempts: m.ReconnectAttempts,
		}
		if m.OnId != nil {
			cfg.OnId = func(id PeerId) {
				m.OnId(addr, id)
			}
		}
		client, err = NewClient(cfg)
		if err != nil {
			return nil, err
		}
		m.clients[addr] = client
	}
	return client, nil
}

// Close closes this ClientMgr and all managed clients.
func (m *ClientMgr) Close() []error {
	errors := make([]error, 0)
	m.clientsMutex.Lock()
	defer m.clientsMutex.Unlock()
	for _, client := range m.clients {
		err := client.Close()
		if err != nil {
			errors = append(errors, err)
		}
	}
	if len(errors) == 0 {
		return nil
	}
	return errors
}
