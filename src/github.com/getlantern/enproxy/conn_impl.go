package enproxy

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"

	"code.google.com/p/go-uuid/uuid"
	"github.com/getlantern/idletiming"
)

// Dial creates a Conn, opens a connection to the proxy and starts processing
// writes and reads on the Conn.
//
// addr: the host:port of the destination server that we're trying to reach
//
// config: configuration for this Conn
func Dial(addr string, config *Config) (net.Conn, error) {
	c := &conn{
		id:     uuid.NewRandom().String(),
		addr:   addr,
		config: config,
	}

	c.initDefaults()
	c.makeChannels()
	c.initRequestStrategy()

	// Dial proxy
	proxyConn, err := c.dialProxy()
	if err != nil {
		return nil, fmt.Errorf("Unable to dial proxy to %s: %s", addr, err)
	}

	go c.processWrites()
	go c.processReads()
	go c.processRequests(proxyConn)

	increment(&open)

	return idletiming.Conn(c, c.config.IdleTimeout, func() {
		log.Debugf("Proxy connection to %s via %s idle for %v, closing", addr, proxyConn.conn.RemoteAddr(), c.config.IdleTimeout)
		if err := c.Close(); err != nil {
			log.Debugf("Unable to close connection: %v", err)
		}
		// Close the initial proxyConn just in case
		if err := proxyConn.conn.Close(); err != nil {
			log.Debugf("Unable to close proxy connection: %v", err)
		}
	}), nil
}

func (c *conn) initDefaults() {
	if c.config.FlushTimeout == 0 {
		c.config.FlushTimeout = defaultWriteFlushTimeout
	}
	if c.config.IdleTimeout == 0 {
		c.config.IdleTimeout = defaultIdleTimeoutClient
	}
}

func (c *conn) makeChannels() {
	// All channels are buffered to prevent deadlocks
	c.initialResponseCh = make(chan hostWithResponse, 1)
	c.writeRequestsCh = make(chan []byte, 1)
	c.writeResponsesCh = make(chan rwResponse, 1)
	c.readRequestsCh = make(chan []byte, 1)
	c.readResponsesCh = make(chan rwResponse, 1)
	c.requestOutCh = make(chan *request, 1)
	c.requestFinishedCh = make(chan error, 1)

	// Buffered to depth 2 because we report async errors to the reading and
	// writing goroutines.
	c.asyncErrCh = make(chan error, 2)

	// Buffered so that even if conn.Close() hasn't been called, we can report
	// finished.
	c.doneWritingCh = make(chan bool, 1)
	c.doneReadingCh = make(chan bool, 1)
	c.doneRequestingCh = make(chan bool, 1)
}

func (c *conn) initRequestStrategy() {
	if c.config.BufferRequests {
		c.rs = &bufferingRequestStrategy{
			c: c,
		}
	} else {
		c.rs = &streamingRequestStrategy{
			c: c,
		}
	}
}

func (c *conn) dialProxy() (*connInfo, error) {
	conn, err := c.config.DialProxy(c.addr)
	if err != nil {
		msg := fmt.Errorf("Unable to dial proxy to %s: %s", c.addr, err)
		log.Debug(msg)
		return nil, msg
	}
	proxyConn := &connInfo{
		bufReader: bufio.NewReader(conn),
	}
	proxyConn.conn = idletiming.Conn(conn, c.config.IdleTimeout, func() {
		// When the underlying connection times out, mark the connInfo closed
		proxyConn.closedMutex.Lock()
		defer proxyConn.closedMutex.Unlock()
		proxyConn.closed = true
	})
	return proxyConn, nil
}

func (c *conn) redialProxyIfNecessary(proxyConn *connInfo) (*connInfo, error) {
	proxyConn.closedMutex.Lock()
	defer proxyConn.closedMutex.Unlock()
	if proxyConn.closed || proxyConn.conn.TimesOutIn() < oneSecond {
		if err := proxyConn.conn.Close(); err != nil {
			log.Debugf("Unable to close proxy connection: %v", err)
		}
		return c.dialProxy()
	} else {
		return proxyConn, nil
	}
}

func (c *conn) doRequest(proxyConn *connInfo, host string, op string, request *request) (resp *http.Response, err error) {
	var body io.Reader
	if request != nil {
		body = request.body
	}
	path := c.id + "/" + c.addr + "/" + op
	req, err := c.config.NewRequest(host, path, "POST", body)
	if err != nil {
		err = fmt.Errorf("Unable to construct request to %s via proxy %s: %s", c.addr, host, err)
		return
	}
	//req.Header.Set(X_ENPROXY_OP, op)
	// Always send our connection id
	//req.Header.Set(X_ENPROXY_ID, c.id)
	// Always send the address that we're trying to reach
	//req.Header.Set(X_ENPROXY_DEST_ADDR, c.addr)
	req.Header.Set("Content-type", "application/octet-stream")
	if request != nil && request.length > 0 {
		// Force identity encoding to appeas CDNs like Fastly that can't
		// handle chunked encoding on requests
		req.TransferEncoding = []string{"identity"}
		req.ContentLength = int64(request.length)
	} else {
		req.ContentLength = 0
	}

	err = req.Write(proxyConn.conn)
	if err != nil {
		err = fmt.Errorf("Error sending request to %s via proxy %s: %s", c.addr, host, err)
		return
	}

	resp, err = http.ReadResponse(proxyConn.bufReader, req)
	if err != nil {
		err = fmt.Errorf("Error reading response from proxy: %s", err)
		return
	}

	// Check response status
	responseOK := resp.StatusCode >= 200 && resp.StatusCode < 300
	if !responseOK {
		// This means we're getting something other than an OK response from the fronting provider
		// itself, which is odd. Try to log the entire response for easier debugging.
		full, er := httputil.DumpResponse(resp, true)
		if er == nil {
			err = fmt.Errorf("Bad response status for read from fronting provider: %s", string(full))
		} else {
			log.Errorf("Could not dump response: %v", er)
			err = fmt.Errorf("Bad response status for read from fronting provider: %s", resp.Status)
		}
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
		resp = nil
	} else {
		log.Debugf("Got OK from fronting provider")
	}

	return
}

type closer struct {
	io.Reader
}

func (r *closer) Close() error {
	return nil
}
