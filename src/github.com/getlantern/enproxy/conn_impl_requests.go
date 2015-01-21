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
func (c *conn) processRequests(proxyConn *connInfo) {
	increment(&requesting)

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
		decrement(&writingRequestPending)
		increment(&writingProcessingRequestRedialing)
		proxyConn, err = c.redialProxyIfNecessary(proxyConn)
		decrement(&writingProcessingRequestRedialing)
		if err != nil {
			c.fail(mkerror("Unable to redial proxy", err))
			return
		}

		// Then issue new request
		increment(&writingProcessingRequest)
		resp, err = c.doRequest(proxyConn, proxyHost, OP_WRITE, request)
		decrement(&writingProcessingRequest)
		log.Tracef("Issued write request with result: %v", err)
		increment(&writingProcessingRequestPostingRequestFinished)
		c.requestFinishedCh <- err
		decrement(&writingProcessingRequestPostingRequestFinished)
		if err != nil {
			c.fail(mkerror("Unable to issue write request", err))
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
			increment(&writingProcessingRequestPostingResponse)
			c.initialResponseCh <- hostWithResponse{
				proxyHost: proxyHost,
				proxyConn: proxyConn,
				resp:      resp,
			}
			decrement(&writingProcessingRequestPostingResponse)

			first = false

			// Dial again because our old proxyConn is now being used by the
			// reader goroutine
			increment(&writingProcessingRequestDialingFirst)
			proxyConn, err = c.dialProxy()
			decrement(&writingProcessingRequestDialingFirst)
			if err != nil {
				c.fail(mkerror("Unable to dial proxy for 2nd request", err))
				return
			}
		}
	}
}

// submitRequest submits a request to the processRequests goroutine, returning
// true if the request was accepted or false if requests are no longer being
// accepted
func (c *conn) submitRequest(request *request) bool {
	c.closingMutex.RLock()
	defer c.closingMutex.RUnlock()
	if c.closing {
		return false
	} else {
		increment(&writingRequestPending)
		c.requestOutCh <- request
		return true
	}
}

func (c *conn) finishRequesting(resp *http.Response, first bool) {
	increment(&requestingFinishing)
	close(c.initialResponseCh)
	if !first && resp != nil {
		resp.Body.Close()
	}
	// Drain requestsOutCh
	for req := range c.requestOutCh {
		decrement(&writingRequestPending)
		req.body.Close()
	}
	c.doneRequestingCh <- true
	decrement(&requestingFinishing)
	decrement(&requesting)
	return
}
