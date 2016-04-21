package enproxy

import (
	"bytes"
	"io"
)

// request is an outgoing request to the upstream proxy
type request struct {
	body   io.ReadCloser
	length int
}

// requestStrategy encapsulates a strategy for making requests upstream (either
// buffered or streaming)
type requestStrategy interface {
	write(b []byte) (int, error)

	finishBody() error
}

// bufferingRequestStrategy is an implementation of requestStrategy that buffers
// requests upstream.
type bufferingRequestStrategy struct {
	c                   *conn
	currentBody         []byte
	currentBytesWritten int
}

// streamingRequestStrategy is an implementation of requestStrategy that streams
// requests upstream.
type streamingRequestStrategy struct {
	c      *conn
	writer *io.PipeWriter
}

// Writes the given buffer to the upstream proxy encapsulated in an HTTP
// request. If b is bigger than bodySize (65K), then this will result in
// multiple POST requests.
func (brs *bufferingRequestStrategy) write(b []byte) (int, error) {
	// Consume writes as long as they keep coming in
	bytesWritten := 0

	// Copy from b into outbound body
	for {
		bytesRemaining := bodySize - brs.currentBytesWritten
		bytesToCopy := len(b)
		if bytesToCopy == 0 {
			break
		} else {
			if brs.currentBody == nil {
				brs.initBody()
			}
			dst := brs.currentBody[brs.currentBytesWritten:]
			if bytesToCopy <= bytesRemaining {
				// Copy the entire buffer to the destination
				copy(dst, b)
				brs.currentBytesWritten = brs.currentBytesWritten + bytesToCopy
				bytesWritten = bytesWritten + bytesToCopy
				break
			} else {
				// Copy as much as we can from the buffer to the destination
				copy(dst, b[:bytesRemaining])
				// Set buffer to remaining bytes
				b = b[bytesRemaining:]
				brs.currentBytesWritten = brs.currentBytesWritten + bytesRemaining
				bytesWritten = bytesWritten + bytesRemaining
				// Write the body
				err := brs.finishBody()
				if err != nil {
					return 0, err
				}
			}
		}
	}

	if bodySize == brs.currentBytesWritten {
		// We've filled the body, write it
		err := brs.finishBody()
		if err != nil {
			return 0, err
		}
	}

	return bytesWritten, nil
}

// Writes the given buffer to the upstream proxy encapsulated in an HTTP
// request.
func (srs *streamingRequestStrategy) write(b []byte) (int, error) {
	if srs.writer == nil {
		// Lazily initialize our next request to the proxy
		// Construct a pipe for piping data to proxy
		reader, writer := io.Pipe()
		increment(&writePipeOpen)
		srs.writer = writer
		request := &request{
			body:   reader,
			length: 0, // forces chunked encoding
		}
		increment(&writingSubmittingRequest)
		if !srs.c.submitRequest(request) {
			decrement(&writingSubmittingRequest)
			return 0, io.EOF
		}
		decrement(&writingSubmittingRequest)
		go func() {
			// Drain the requestFinishedCh
			err := <-srs.c.requestFinishedCh
			if err := writer.Close(); err != nil {
				log.Debugf("Unable to close writer: %v", err)
			}
			if err != nil && err != io.EOF {
				srs.c.fail(err)
			}
		}()
	}

	increment(&writingDoingWrite)
	defer decrement(&writingDoingWrite)
	return srs.writer.Write(b)
}

func (brs *bufferingRequestStrategy) initBody() {
	brs.currentBody = make([]byte, bodySize)
	brs.currentBytesWritten = 0
}

func (brs *bufferingRequestStrategy) finishBody() error {
	if brs.currentBody == nil {
		return nil
	}

	body := brs.currentBody
	if brs.currentBytesWritten < len(brs.currentBody) {
		body = brs.currentBody[:brs.currentBytesWritten]
	}
	success := brs.c.submitRequest(&request{
		body:   &closer{bytes.NewReader(body)},
		length: brs.currentBytesWritten, // forces identity encoding
	})
	if success {
		err := <-brs.c.requestFinishedCh
		if err != nil {
			return err
		}
	}
	brs.currentBody = nil
	brs.currentBytesWritten = 0
	if !success {
		return io.EOF
	}

	return nil
}

func (srs *streamingRequestStrategy) finishBody() error {
	if srs.writer == nil {
		return nil
	}

	if err := srs.writer.Close(); err != nil {
		log.Debugf("Unable to close writer: %v", err)
	}
	srs.writer = nil
	decrement(&writePipeOpen)

	return nil
}
