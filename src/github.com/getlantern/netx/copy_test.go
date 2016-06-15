package netx

import (
	"io"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/stretchr/testify/assert"
)

func TestSimulatedProxy(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	var wg sync.WaitGroup
	wg.Add(2)
	// Start "server"
	ls, err := net.Listen("tcp", ":0")
	if !assert.NoError(t, err, "Server unable to listen") {
		return
	}

	go func() {
		defer ls.Close()
		conn, err := ls.Accept()
		if !assert.NoError(t, err, "Server unable to accept") {
			return
		}
		defer conn.Close()
		b := make([]byte, 5)
		_, err = io.ReadFull(conn, b)
		if !assert.NoError(t, err, "Unable to read from proxy") {
			return
		}
		_, err = conn.Write(b)
		assert.NoError(t, err, "Unable to write to proxy")
		wg.Done()
	}()

	// Start "proxy"
	lp, err := net.Listen("tcp", ":0")
	if !assert.NoError(t, err, "Proxy unable to listen") {
		return
	}

	go func() {
		defer lp.Close()
		in, err := lp.Accept()
		if !assert.NoError(t, err, "Proxy unable to accept") {
			return
		}
		defer in.Close()

		out, err := net.DialTimeout("tcp", ls.Addr().String(), 250*time.Millisecond)
		if !assert.NoError(t, err, "Proxy unable to dial server") {
			return
		}
		defer out.Close()

		errOut, errIn := BidiCopy(out, in, make([]byte, 32768), make([]byte, 32768))
		assert.NoError(t, errOut, "Error copying to server")
		assert.NoError(t, errIn, "Error copying to client")
		wg.Done()
	}()

	// Mimic client
	conn, err := net.DialTimeout("tcp", lp.Addr().String(), 250*time.Millisecond)
	if !assert.NoError(t, err, "Unable to dial") {
		return
	}

	data := []byte("Hello copying world")
	_, err = conn.Write(data)
	if !assert.NoError(t, err, "Unable to write from client") {
		return
	}
	read := make([]byte, 5)
	n, err := io.ReadFull(conn, read)
	if !assert.NoError(t, err, "Unable to read to client") {
		return
	}
	if !assert.EqualValues(t, 5, n, "Wrong amount of data read by client") {
		return
	}
	assert.Equal(t, "Hello", string(read), "Client read wrong data")
	conn.Close()

	wg.Wait()
	defer func() {
		err := fdc.AssertDelta(0)
		if err != nil {
			t.Error(err)
		}
	}()
}
