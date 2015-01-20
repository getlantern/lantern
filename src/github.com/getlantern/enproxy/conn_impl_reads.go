package enproxy

import (
	"fmt"
	"io"
	"net/http"
)

// processReads processes read requests by polling the proxy with GET requests
// and reading the data from the resulting response body
func (c *Conn) processReads() {
	// Wait for connection and response from first write request so that we know
	// where to send read requests.
	initialResponse := <-c.initialResponseCh
	err := initialResponse.err
	if err != nil {
		return
	}

	proxyHost := initialResponse.proxyHost
	proxyConn := initialResponse.proxyConn
	resp := initialResponse.resp

	defer c.finishReading(resp)

	defer func() {
		// If there's a proxyConn at the time that processReads() exits, close
		// it.
		if proxyConn != nil {
			proxyConn.conn.Close()
		}
	}()

	mkerror := func(text string, err error) error {
		return fmt.Errorf("Dest: %s    ProxyHost: %s    %s: %s", c.addr, proxyHost, text, err)
	}

	for b := range c.readRequestsCh {
		if resp == nil {
			// Old response finished
			if c.isIdle() {
				// We're idle, don't bother reading again
				c.readResponsesCh <- rwResponse{0, io.EOF}
				return
			}

			proxyConn, err = c.redialProxyIfNecessary(proxyConn)
			if err != nil {
				c.readResponsesCh <- rwResponse{0, mkerror("Unable to redial proxy", err)}
				return
			}

			resp, err = c.doRequest(proxyConn, proxyHost, OP_READ, nil)
			if err != nil {
				err = mkerror("Unable to issue read request", err)
				log.Error(err)
				c.readResponsesCh <- rwResponse{0, err}
				return
			}
		}

		n, err := resp.Body.Read(b)
		if n > 0 {
			c.markActive()
		}

		hitEOFUpstream := resp.Header.Get(X_ENPROXY_EOF) == "true"
		errToClient := err
		if err == io.EOF && !hitEOFUpstream {
			// The current response hit EOF, but we haven't hit EOF upstream
			// so suppress EOF to reader
			errToClient = nil
		}
		c.readResponsesCh <- rwResponse{n, errToClient}

		if err != nil {
			if err == io.EOF {
				// Current response is done
				resp.Body.Close()
				resp = nil
				if hitEOFUpstream {
					// True EOF, stop reading
					return
				}
				continue
			} else {
				log.Errorf("Error reading: %s", err)
				return
			}
		}
	}
}

// submitRead submits a read to the processReads goroutine, returning true if
// the read was accepted or false if reads are no longer being accepted
func (c *Conn) submitRead(b []byte) bool {
	c.closedMutex.RLock()
	defer c.closedMutex.RUnlock()
	if c.closed {
		return false
	} else {
		c.readRequestsCh <- b
		return true
	}
}

func (c *Conn) finishReading(resp *http.Response) {
	if resp != nil {
		resp.Body.Close()
	}
	c.doneReadingCh <- true
	return
}
