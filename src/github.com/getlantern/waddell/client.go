package waddell

import (
	"crypto/tls"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/getlantern/keyman"
)

var (
	maxReconnectDelay      = 5 * time.Second
	reconnectDelayInterval = 100 * time.Millisecond

	closedError = fmt.Errorf("Client closed")
)

type ClientConfig struct {
	// Dial is a function that dials the waddell server
	Dial DialFunc

	// ServerCert: PEM-encoded certificate by which to authenticate the waddell
	// server. If provided, connection to waddell is encrypted with TLS. If not,
	// connection will be made plain-text.
	ServerCert string

	// ReconnectAttempts specifies how many consecutive times to try
	// reconnecting in the event of a connection failure.
	//
	// Note - when auto reconnecting is enabled, the client will never resend
	// messages, it will simply reopen the connection.
	ReconnectAttempts int

	// OnId allows optionally registering a callback to be notified whenever a
	// PeerId is assigned to this client (i.e. on each successful connection to
	// the waddell server).
	OnId func(id PeerId)
}

// Client is a client of a waddell server
type Client struct {
	*ClientConfig

	connInfoChs    chan chan *connInfo
	connErrCh      chan error
	topicsOut      map[TopicId]*topic
	topicsOutMutex sync.Mutex
	topicsIn       map[TopicId]chan *MessageIn
	topicsInMutex  sync.Mutex
	currentId      PeerId
	currentIdMutex sync.RWMutex
	closed         int32
}

// DialFunc is a function for dialing a waddell server.
type DialFunc func() (net.Conn, error)

// NewClient creates a waddell client, including establishing an initial
// connection to the waddell server, returning the client and the initial
// PeerId.
//
// IMPORTANT - clients receive messages on topics. Users of Client are
// responsible for draining all topics on which the Client may receive a
// message, otherwise other topics will block.
//
// Note - if the client automatically reconnects, its peer ID will change. You
// can obtain the new id through providing an OnId callback to the client.
//
// Note - whether or not auto reconnecting is enabled, this method doesn't
// return until a connection has been established or we've failed trying.
func NewClient(cfg *ClientConfig) (*Client, error) {
	c := &Client{
		ClientConfig: cfg,
	}
	var err error
	if c.ServerCert != "" {
		c.Dial, err = secured(c.Dial, c.ServerCert)
		if err != nil {
			return nil, err
		}
	}

	c.connInfoChs = make(chan chan *connInfo)
	c.connErrCh = make(chan error)
	c.topicsOut = make(map[TopicId]*topic)
	c.topicsIn = make(map[TopicId]chan *MessageIn)
	go c.stayConnected()
	go c.processInbound()
	info := c.getConnInfo()
	return c, info.err
}

// CurrentId returns the current id (from most recent connection to waddell).
// To be notified about changes to the id, use the OnId handler.
func (c *Client) CurrentId() PeerId {
	c.currentIdMutex.RLock()
	defer c.currentIdMutex.RUnlock()
	return c.currentId
}

func (c *Client) setCurrentId(id PeerId) {
	c.currentIdMutex.Lock()
	c.currentId = id
	c.currentIdMutex.Unlock()
}

// SendKeepAlive sends a keep alive message to the server to keep the underlying
// connection open.
func (c *Client) SendKeepAlive() error {
	if c.isClosed() {
		return closedError
	}

	info := c.getConnInfo()
	if info.err != nil {
		return info.err
	}
	_, err := info.writer.Write(keepAlive)
	if err != nil {
		c.connError(err)
	}
	return err
}

// Close closes this client, its topics and associated resources.
//
// WARNING - Close() closes the out topic channels. Attempts to write to these
// channels after they're closed will result in a panic. So, don't call Close()
// until you're actually 100% finished using this client.
func (c *Client) Close() error {
	if c == nil {
		return nil
	}

	justClosed := atomic.CompareAndSwapInt32(&c.closed, 0, 1)
	if !justClosed {
		return nil
	}

	var err error
	log.Trace("Closing client")
	c.topicsInMutex.Lock()
	defer c.topicsInMutex.Unlock()
	c.topicsOutMutex.Lock()
	defer c.topicsOutMutex.Unlock()
	for _, t := range c.topicsOut {
		close(t.out)
	}
	for _, ch := range c.topicsIn {
		close(ch)
	}
	info := c.getConnInfo()
	if info.conn != nil {
		err = info.conn.Close()
		log.Trace("Closed client connection")
	}
	close(c.connInfoChs)
	return err
}

// secured wraps the given dial function with TLS support, authenticating the
// waddell server using the supplied cert (assumed to be PEM encoded).
func secured(dial DialFunc, cert string) (DialFunc, error) {
	c, err := keyman.LoadCertificateFromPEMBytes([]byte(cert))
	if err != nil {
		return nil, err
	}
	tlsConfig := &tls.Config{
		RootCAs:    c.PoolContainingCert(),
		ServerName: c.X509().Subject.CommonName,
	}
	return func() (net.Conn, error) {
		conn, err := dial()
		if err != nil {
			return nil, err
		}
		return tls.Client(conn, tlsConfig), nil
	}, nil
}

func (c *Client) isClosed() bool {
	return c.closed == 1
}
