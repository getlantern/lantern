package enproxy

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"time"

	"code.google.com/p/go-uuid/uuid"
	"github.com/getlantern/idletiming"
)

// Connect opens a connection to the proxy and starts processing writes and
// reads to this Conn.
func (c *Conn) Connect() error {
	c.id = uuid.NewRandom().String()

	c.initDefaults()
	c.makeChannels()
	c.markActive()
	c.initRequestStrategy()

	go c.processWrites()
	go c.processReads()

	// Dial proxy
	proxyConn, err := c.dialProxy()
	if err != nil {
		return fmt.Errorf("Unable to dial proxy: %s", err)
	}

	go c.processRequests(proxyConn)

	return nil
}

func (c *Conn) initDefaults() {
	if c.Config.FlushTimeout == 0 {
		c.Config.FlushTimeout = defaultWriteFlushTimeout
	}
	if c.Config.IdleTimeout == 0 {
		c.Config.IdleTimeout = defaultIdleTimeoutClient
	}
}

func (c *Conn) makeChannels() {
	c.initialResponseCh = make(chan hostWithResponse)
	c.writeRequestsCh = make(chan []byte)
	c.writeResponsesCh = make(chan rwResponse)
	c.stopWriteCh = make(chan interface{}, closeChannelDepth)
	c.readRequestsCh = make(chan []byte)
	c.readResponsesCh = make(chan rwResponse)
	c.stopReadCh = make(chan interface{}, closeChannelDepth)
	c.requestOutCh = make(chan *request)
	c.requestFinishedCh = make(chan error)
	c.stopRequestCh = make(chan interface{}, closeChannelDepth)
}

func (c *Conn) initRequestStrategy() {
	if c.Config.BufferRequests {
		c.rs = &bufferingRequestStrategy{
			c: c,
		}
	} else {
		c.rs = &streamingRequestStrategy{
			c: c,
		}
	}
}

func (c *Conn) dialProxy() (*connInfo, error) {
	conn, err := c.Config.DialProxy(c.Addr)
	if err != nil {
		return nil, fmt.Errorf("Unable to dial proxy: %s", err)
	}
	proxyConn := &connInfo{
		bufReader: bufio.NewReader(conn),
	}
	proxyConn.conn = idletiming.Conn(conn, c.Config.IdleTimeout, func() {
		// When the underlying connection times out, mark the connInfo closed
		proxyConn.closedMutex.Lock()
		defer proxyConn.closedMutex.Unlock()
		proxyConn.closed = true
	})
	return proxyConn, nil
}

func (c *Conn) redialProxyIfNecessary(proxyConn *connInfo) (*connInfo, error) {
	proxyConn.closedMutex.Lock()
	defer proxyConn.closedMutex.Unlock()
	if proxyConn.closed || proxyConn.conn.TimesOutIn() < oneSecond {
		proxyConn.conn.Close()
		return c.dialProxy()
	} else {
		return proxyConn, nil
	}
}

func (c *Conn) doRequest(proxyConn *connInfo, host string, op string, request *request) (resp *http.Response, err error) {
	var body io.Reader
	if request != nil {
		body = request.body
	}
	req, err := c.Config.NewRequest(host, "POST", body)
	if err != nil {
		err = fmt.Errorf("Unable to construct request to proxy: %s", err)
		return
	}
	req.Header.Set(X_ENPROXY_OP, op)
	// Always send our connection id
	req.Header.Set(X_ENPROXY_ID, c.id)
	// Always send the address that we're trying to reach
	req.Header.Set(X_ENPROXY_DEST_ADDR, c.Addr)
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
		err = fmt.Errorf("Error sending request to proxy: %s", err)
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
		err = fmt.Errorf("Bad response status for read: %s", resp.Status)
		resp.Body.Close()
		resp = nil
	}

	return
}

func (c *Conn) markActive() {
	c.lastActivityMutex.Lock()
	defer c.lastActivityMutex.Unlock()
	c.lastActivityTime = time.Now()
}

func (c *Conn) isIdle() bool {
	c.lastActivityMutex.RLock()
	defer c.lastActivityMutex.RUnlock()
	timeSinceLastActivity := time.Now().Sub(c.lastActivityTime)
	return timeSinceLastActivity > c.Config.IdleTimeout
}

type closer struct {
	io.Reader
}

func (r *closer) Close() error {
	return nil
}
