package enproxy

import (
	"bufio"
	"io"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/getlantern/golog"
	"github.com/getlantern/idletiming"
)

const (
	X_ENPROXY_ID         = "X-Enproxy-Id"
	X_ENPROXY_DEST_ADDR  = "X-Enproxy-Dest-Addr"
	X_ENPROXY_EOF        = "X-Enproxy-EOF"
	X_ENPROXY_PROXY_HOST = "X-Enproxy-Proxy-Host"
	X_ENPROXY_OP         = "X-Enproxy-Op"

	OP_WRITE = "write"
	OP_READ  = "read"
)

var (
	log = golog.LoggerFor("enproxy")
)

var (
	defaultWriteFlushTimeout = 35 * time.Millisecond
	defaultReadFlushTimeout  = 35 * time.Millisecond
	defaultIdleTimeoutClient = 30 * time.Second
	defaultIdleTimeoutServer = 70 * time.Second

	// closeChannelDepth: controls depth of channels used for close processing.
	// Doesn't need to be particularly big, as it's just used to prevent
	// deadlocks on multiple calls to Close().
	closeChannelDepth = 20

	bodySize = 65536 // size of buffer used for request bodies

	oneSecond = 1 * time.Second
)

// Conn is a net.Conn that tunnels its data via an httpconn.Proxy using HTTP
// requests and responses.  It assumes that streaming requests are not supported
// by the underlying servers/proxies, and so uses a polling technique similar to
// the one used by meek, but different in that data is not encoded as JSON.
// https://trac.torproject.org/projects/tor/wiki/doc/AChildsGardenOfPluggableTransports#Undertheencryption.
//
// enproxy uses two parallel channels to send and receive data.  One channel
// handles writing data out by making sequential POST requests to the server
// which encapsulate the outbound data in their request bodies, while the other
// channel handles reading data by making GET requests and grabbing the data
// encapsulated in the response bodies.
//
// Write Channel:
//
//   1. Accept writes, piping these to the proxy as the body of an http POST
//   2. Continue to pipe the writes until the pause between consecutive writes
//      exceeds the IdleInterval, at which point we finish the request body. We
//      do this because it is assumed that intervening proxies (e.g. CloudFlare
//      CDN) do not allow streaming requests, so it is necessary to finish the
//      request for data to get flushed to the destination server.
//   3. After receiving a response to the POST request, return to step 1
//
// Read Channel:
//
//   1. Accept reads, issuing a new GET request if one is not already ongoing
//   2. Process read by grabbing data from the response to the GET request
//   3. Continue to accept reads, grabbing these from the response of the
//      existing GET request
//   4. Once the response to the GET request reaches EOF, return to step 1. This
//      will happen because the proxy periodically closes responses to make sure
//      intervening proxies don't time out.
//   5. If a response is received with a special header indicating a true EOF
//      from the destination server, return EOF to the reader
//
type conn struct {
	// addr: the host:port of the destination server that we're trying to reach
	addr string

	// config: configuration of this Conn
	config *Config

	// initialResponseCh: Self-reported FQDN of the proxy serving this connection
	// plus initial response from proxy.
	//
	// This allows us to guarantee we reach the same server in subsequent
	// requests, even if it was initially reached through a FQDN that may
	// resolve to different IPs in different DNS lookups (e.g. as in DNS round
	// robin).
	initialResponseCh chan hostWithResponse

	// id: unique identifier for this connection. This is used by the Proxy to
	// associate requests from this connection to the corresponding outbound
	// connection on the Proxy side.  It is populated using a type 4 UUID.
	id string

	/* Write processing */
	writeRequestsCh  chan []byte     // requests to write
	writeResponsesCh chan rwResponse // responses for writes
	doneWritingCh    chan bool
	rs               requestStrategy

	/* Request processing (for writes) */
	requestOutCh      chan *request // channel for next outgoing request body
	requestFinishedCh chan error
	doneRequestingCh  chan bool

	/* Read processing */
	readRequestsCh  chan []byte     // requests to read
	readResponsesCh chan rwResponse // responses for reads
	doneReadingCh   chan bool

	/* Fields for tracking error and closed status */
	asyncErr      error        // error that occurred during asynchronous processing
	asyncErrMutex sync.RWMutex // mutex guarding asyncErr
	asyncErrCh    chan error   // channel used to interrupted any waiting reads/writes with an async error
	closing       bool         // whether or not this Conn is closing
	closingMutex  sync.RWMutex // mutex controlling access to the closing flag

	/* Track current response */
	resp *http.Response // the current response being used to read data
}

// Config configures a Conn
type Config struct {
	// DialProxy: function to open a connection to the proxy
	DialProxy dialFunc

	// NewRequest: function to create a new request to the proxy
	NewRequest newRequestFunc

	// OnFirstResponse: optional callback that gets called on the first response
	// from the proxy.
	OnFirstResponse func(resp *http.Response)

	// FlushTimeout: how long to let writes idle before writing out a
	// request to the proxy.  Defaults to 15 milliseconds.
	FlushTimeout time.Duration

	// IdleTimeout: how long to wait before closing an idle connection, defaults
	// to 30 seconds on the client and 70 seconds on the server proxy.
	//
	// For clients, the value should be set lower than the proxy's idle timeout
	// so that enproxy redials before the active connection is closed. The value
	// should be set higher than the maximum possible time between the proxy
	// receiving the last data from a request and the proxy returning the first
	// data of the response, otherwise the connection will be closed in the
	// middle of processing a request.
	IdleTimeout time.Duration

	// BufferRequests: if true, requests to the proxy will be buffered and sent
	// with identity encoding.  If false, they'll be streamed with chunked
	// encoding.
	BufferRequests bool
}

// dialFunc is a function that dials an address (e.g. the upstream proxy)
type dialFunc func(addr string) (net.Conn, error)

// newRequestFunc is a function that builds a new request to the upstream proxy
type newRequestFunc func(host, path, method string, body io.Reader) (*http.Request, error)

// rwResponse is a response to a read or write
type rwResponse struct {
	n   int
	err error
}

type connInfo struct {
	conn        *idletiming.IdleTimingConn
	bufReader   *bufio.Reader
	closed      bool
	closedMutex sync.Mutex
}

type hostWithResponse struct {
	proxyHost string
	proxyConn *connInfo
	resp      *http.Response
}

// Write() implements the function from net.Conn
func (c *conn) Write(b []byte) (n int, err error) {
	err = c.getAsyncErr()
	if err != nil {
		return
	}

	if c.submitWrite(b) {
		defer decrement(&blockedOnWrite)

		select {
		case res, ok := <-c.writeResponsesCh:
			if !ok {
				return 0, io.EOF
			} else {
				return res.n, res.err
			}
		case err := <-c.asyncErrCh:
			return 0, err
		}
	} else {
		return 0, io.EOF
	}
}

// Read() implements the function from net.Conn
func (c *conn) Read(b []byte) (n int, err error) {
	err = c.getAsyncErr()
	if err != nil {
		return
	}

	if c.submitRead(b) {
		defer decrement(&blockedOnRead)

		select {
		case res, ok := <-c.readResponsesCh:
			if !ok {
				return 0, io.EOF
			} else {
				return res.n, res.err
			}
		case err := <-c.asyncErrCh:
			return 0, err
		}
	} else {
		return 0, io.EOF
	}
}

func (c *conn) fail(err error) {
	log.Debugf("Failing on %v", err)

	c.asyncErrMutex.Lock()
	if c.asyncErr != nil {
		c.asyncErr = err
	}
	c.asyncErrMutex.Unlock()

	// Let any waiting readers or writers know about the error
	for i := 0; i < 2; i++ {
		select {
		case c.asyncErrCh <- err:
			// submitted okay
		default:
			// channel full, continue
		}
	}

	go func() {
		if err := c.Close(); err != nil {
			log.Debugf("Unable to close connection: %v", err)
		}
	}()
}

func (c *conn) getAsyncErr() error {
	c.asyncErrMutex.RLock()
	err := c.asyncErr
	c.asyncErrMutex.RUnlock()
	return err
}

// Close() implements the function from net.Conn
func (c *conn) Close() error {
	increment(&closing)
	defer decrement(&closing)

	c.closingMutex.Lock()
	wasClosing := c.closing
	c.closing = true
	c.closingMutex.Unlock()
	if !wasClosing {
		increment(&blockedOnClosing)
		close(c.writeRequestsCh)
		close(c.readRequestsCh)
		<-c.doneReadingCh
		<-c.doneWritingCh
		<-c.doneRequestingCh
		decrement(&blockedOnClosing)
		decrement(&open)
	}
	return nil
}

// LocalAddr() is not implemented
func (c *conn) LocalAddr() net.Addr {
	panic("LocalAddr() not implemented")
}

// RemoteAddr() is not implemented
func (c *conn) RemoteAddr() net.Addr {
	panic("RemoteAddr() not implemented")
}

// SetDeadline() is currently unimplemented.
func (c *conn) SetDeadline(t time.Time) error {
	log.Tracef("SetDeadline not implemented")
	return nil
}

// SetReadDeadline() is currently unimplemented.
func (c *conn) SetReadDeadline(t time.Time) error {
	log.Tracef("SetReadDeadline not implemented")
	return nil
}

// SetWriteDeadline() is currently unimplemented.
func (c *conn) SetWriteDeadline(t time.Time) error {
	log.Tracef("SetWriteDeadline not implemented")
	return nil
}
