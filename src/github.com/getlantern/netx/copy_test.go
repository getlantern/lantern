package netx

import (
	"io"
	"io/ioutil"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/stretchr/testify/assert"
)

func TestSimulatedProxy(t *testing.T) {
	originalCopyTimeout := copyTimeout
	copyTimeout = 5 * time.Millisecond
	defer func() {
		copyTimeout = originalCopyTimeout
	}()
	data := make([]byte, 30000000)
	for i := 0; i < len(data); i++ {
		data[i] = 5
	}

	writeTimeout := copyTimeout * 25

	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	var wg sync.WaitGroup
	wg.Add(2)
	// Start "server"
	ls, err := net.Listen("tcp4", ":0")
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
		b := make([]byte, len(data))
		_, err = io.ReadFull(conn, b)
		if !assert.NoError(t, err, "Unable to read from proxy") {
			return
		}
		_, err = conn.Write(b)
		assert.NoError(t, err, "Error writing to proxy")
		// Keep reading from the connection until the client closes it
		io.Copy(ioutil.Discard, conn)
		wg.Done()
	}()

	// Start "proxy"
	lp, err := net.Listen("tcp4", ":0")
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

		out, err := net.DialTimeout("tcp4", ls.Addr().String(), 250*time.Millisecond)
		if !assert.NoError(t, err, "Proxy unable to dial server") {
			return
		}
		defer out.Close()

		errOut, errIn := BidiCopy(out, in, make([]byte, 32768), make([]byte, 32768), writeTimeout)
		assert.NoError(t, errOut, "Error copying to server")
		assert.NoError(t, errIn, "Error copying to client")
		wg.Done()
	}()

	// Mimic client
	conn, err := net.DialTimeout("tcp4", lp.Addr().String(), 250*time.Millisecond)
	if !assert.NoError(t, err, "Unable to dial") {
		return
	}

	_, err = conn.Write(data)
	if !assert.NoError(t, err, "Unable to write from client") {
		return
	}
	read := make([]byte, len(data))
	n, err := io.ReadFull(conn, read)
	if !assert.NoError(t, err, "Unable to read to client") {
		return
	}
	if assert.Equal(t, len(data), n, "Read wrong amount of data") {
		assert.EqualValues(t, data, read, "Client read wrong data")
	}
	conn.Close()

	wg.Wait()
	defer func() {
		err := fdc.AssertDelta(0)
		if err != nil {
			t.Error(err)
		}
	}()
}
