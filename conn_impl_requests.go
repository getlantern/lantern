package enproxy

import (
	"fmt"
	"io"
	"net/http"
	"time"
)

// processRequests handles writing outbound requests to the proxy.  Note - this
// is not pipelined, because we cannot be sure that intervening proxies will
// deliver requests to the enproxy server in order. In-order delivery is
// required because we are encapsulating a stream of data inside the bodies of
// successive requests.
func (c *Conn) processRequests(proxyConn *connInfo) {
	var resp *http.Response

	first := true
	defer c.cleanupAfterRequests(resp, first)

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
		return fmt.Errorf("Dest: %s    ProxyHost: %s    %s: %s", c.Addr, proxyHost, text, err)
	}

	for {
		if c.isClosed() {
			return
		}

		select {
		case request := <-c.requestOutCh:
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
			c.requestFinishedCh <- err
			if err != nil {
				err = mkerror("Unable to issue write request", err)
				log.Error(err)
				if first {
					c.initialResponseCh <- hostWithResponse{err: err}
				}
				return
			}

			if first {
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
			} else {
				resp.Body.Close()
			}
		case <-c.stopRequestCh:
			return
		case <-time.After(c.Config.IdleTimeout):
			if c.isIdle() {
				return
			}
		}
	}
}

// submitRequest submits a request to the processRequests goroutine, returning
// true if the request was accepted or false if requests are no longer being
// accepted
func (c *Conn) submitRequest(request *request) bool {
	c.requestMutex.RLock()
	defer c.requestMutex.RUnlock()
	if c.doneRequesting {
		return false
	} else {
		c.requestOutCh <- request
		return true
	}
}

func (c *Conn) cleanupAfterRequests(resp *http.Response, first bool) {
	panicked := recover()

	for {
		select {
		case <-c.requestOutCh:
			if panicked != nil {
				c.requestFinishedCh <- io.ErrUnexpectedEOF
			} else {
				c.requestFinishedCh <- io.EOF
			}
		case <-c.stopRequestCh:
			// do nothing
		default:
			c.requestMutex.Lock()
			c.doneRequesting = true
			c.requestMutex.Unlock()
			close(c.requestOutCh)
			if !first && resp != nil {
				resp.Body.Close()
			}
			return
		}
	}
}
