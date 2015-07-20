package enproxy

import (
	"time"
)

var (
	emptyBytes = []byte{}
)

// processWrites processes write requests by writing them to the body of a POST
// request.  Note - processWrites doesn't actually send the POST requests,
// that's handled by the processRequests goroutine.  The reason that we do this
// on a separate goroutine is that the call to Request.Write() blocks until the
// body has finished, and of course the body is written to as a result of
// processing writes, so we need 2 goroutines to allow us to continue to
// accept writes and pipe these to the request body while actually sending that
// request body to the server.
func (c *conn) processWrites() {
	increment(&writing)

	defer c.finishWriting()

	firstRequest := true
	hasWritten := false

	for {
		increment(&writingSelecting)
		select {
		case b, more := <-c.writeRequestsCh:
			decrement(&writingSelecting)

			if !more {
				return
			}
			hasWritten = true
			if !c.processWrite(b) {
				// There was a problem processing a write, stop
				return
			}
		case <-time.After(c.config.FlushTimeout):
			// We waited more than FlushTimeout for a write, finish our request
			decrement(&writingSelecting)

			if firstRequest && !hasWritten {
				// Write empty data just so that we can get a response and get
				// on with reading.
				// TODO: it might be more efficient to instead start by reading,
				// but that's a fairly big structural change on client and
				// server.
				increment(&writingWritingEmpty)
				c.rs.write(emptyBytes)
				decrement(&writingWritingEmpty)
			}

			increment(&writingFinishingBody)
			c.rs.finishBody()
			decrement(&writingFinishingBody)

			firstRequest = false
		}
	}
}

// processWrite processes a single write request, encapsulated in the body of a
// POST request to the proxy. It uses the configured requestStrategy to process
// the request. It returns true if the write was successful.
func (c *conn) processWrite(b []byte) bool {
	increment(&writingWriting)
	n, err := c.rs.write(b)
	decrement(&writingWriting)

	increment(&writingPostingResponse)
	c.writeResponsesCh <- rwResponse{n, err}
	decrement(&writingPostingResponse)

	return err == nil
}

// submitWrite submits a write to the processWrites goroutine, returning true if
// the write was accepted or false if writes are no longer being accepted
func (c *conn) submitWrite(b []byte) bool {
	c.closingMutex.RLock()
	defer c.closingMutex.RUnlock()
	if c.closing {
		return false
	} else {
		increment(&blockedOnWrite)
		c.writeRequestsCh <- b
		return true
	}
}

func (c *conn) finishWriting() {
	increment(&writingFinishing)
	if c.rs != nil {
		c.rs.finishBody()
	}
	close(c.requestOutCh)
	c.doneWritingCh <- true
	decrement(&writingFinishing)
	decrement(&writing)
	return
}
