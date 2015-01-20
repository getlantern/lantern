package enproxy

import (
	"fmt"
	"net/http"
)

// processRequests handles writing outbound requests to the proxy.  Note - this
// is not pipelined, because we cannot be sure that intervening proxies will
// deliver requests to the enproxy server in order. In-order delivery is
// required because we are encapsulating a stream of data inside the bodies of
// successive requests.
func (c *Conn) processRequests(proxyConn *connInfo) {
	var resp *http.Response

	first := true
	defer c.finishRequesting(resp, first)

	defer func() {
		// If there's a proxyConn at the time that processRequests() exits,
		// close it.
		if !first && proxyConn != nil {
			proxyConn.conn.Close()
		}
	}()

	var err error
	var proxyHost string

	mkerror := func(text string, err error) error {
		return fmt.Errorf("Dest: %s    ProxyHost: %s    %s: %s", c.addr, proxyHost, text, err)
	}

	for request := range c.requestOutCh {
		proxyConn, err = c.redialProxyIfNecessary(proxyConn)
		if err != nil {
			err = mkerror("Unable to redial proxy", err)
			log.Error(err)
			if first {
				c.initialResponseCh <- hostWithResponse{err: err}
			}
			return
		}

		// Then issue new request
		resp, err = c.doRequest(proxyConn, proxyHost, OP_WRITE, request)
		log.Tracef("Issued write request with result: %v", err)
		c.requestFinishedCh <- err
		if err != nil {
			err = mkerror("Unable to issue write request", err)
			log.Error(err)
			if first {
				c.initialResponseCh <- hostWithResponse{err: err}
			}
			return
		}

		if !first {
			resp.Body.Close()
		} else {
			// On our first request, find out what host we're actually
			// talking to and remember that for future requests.
			proxyHost = resp.Header.Get(X_ENPROXY_PROXY_HOST)

			// Also post it to initialResponseCh so that the processReads()
			// routine knows which proxyHost to use and gets the initial
			// response data
			c.initialResponseCh <- hostWithResponse{
				proxyHost: proxyHost,
				proxyConn: proxyConn,
				resp:      resp,
			}

			first = false

			// Dial again because our old proxyConn is now being used by the
			// reader goroutine
			proxyConn, err = c.dialProxy()
			if err != nil {
				err = mkerror("Unable to dial proxy for 2nd request", err)
				log.Error(err)
				return
			}
		}
	}
}

// submitRequest submits a request to the processRequests goroutine, returning
// true if the request was accepted or false if requests are no longer being
// accepted
func (c *Conn) submitRequest(request *request) bool {
	c.closedMutex.RLock()
	defer c.closedMutex.RUnlock()
	if c.closed {
		return false
	} else {
		c.requestOutCh <- request
		return true
	}
}

func (c *Conn) finishRequesting(resp *http.Response, first bool) {
	if !first && resp != nil {
		resp.Body.Close()
	}
	c.doneRequestingCh <- true
	return
}
