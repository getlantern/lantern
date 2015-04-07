package enproxy

import (
	"fmt"
	"io"
	"net/http"
)

// processReads processes read requests by polling the proxy with GET requests
// and reading the data from the resulting response body
func (c *conn) processReads() {
	increment(&reading)

	var resp *http.Response
	var proxyConn *connInfo
	var err error

	defer func() {
		increment(&readingFinishing)
		if resp != nil {
			resp.Body.Close()
		}
		if proxyConn != nil {
			proxyConn.conn.Close()
		}
		c.doneReadingCh <- true
		decrement(&readingFinishing)
		decrement(&reading)
	}()

	// Wait for connection and response from first write request so that we know
	// where to send read requests.
	initialResponse, more := <-c.initialResponseCh
	if !more {
		return
	}

	proxyHost := initialResponse.proxyHost
	proxyConn = initialResponse.proxyConn
	resp = initialResponse.resp

	mkerror := func(text string, err error) error {
		return fmt.Errorf("Dest: %s    ProxyHost: %s    %s: %s", c.addr, proxyHost, text, err)
	}

	for b := range c.readRequestsCh {
		if resp == nil {
			// Old response finished
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
func (c *conn) submitRead(b []byte) bool {
	c.closingMutex.RLock()
	defer c.closingMutex.RUnlock()
	if c.closing {
		return false
	} else {
		increment(&blockedOnRead)
		c.readRequestsCh <- b
		return true
	}
}
