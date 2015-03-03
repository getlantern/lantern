package detour

import (
	"io"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
)

var closeURL string = "http://localhost:12306/close"
var timeOutURL string = "http://localhost:12306/timeout"
var echoURL string = "http://localhost:12306/echo"
var proxiedURL string = "http://localhost:12307"

func closeHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		hj, ok := w.(http.Hijacker)
		if !ok {
			http.Error(w, "webserver doesn't support hijacking", http.StatusInternalServerError)
			return
		}
		conn, _, _ := hj.Hijack()
		conn.Close()
	}
}

func timeOutHandler(d time.Duration) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(d)
		io.Copy(w, r.Body)
		w.(http.Flusher).Flush()
	}
}

type echoHandler struct{}

func (e echoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	io.Copy(w, r.Body)
	w.(http.Flusher).Flush()
}

var blockedListener net.Listener
var echoListener net.Listener
var blockedServer http.Server
var echoServer http.Server

func startMockServers(t *testing.T) {
	var err error
	mux := http.NewServeMux()
	mux.HandleFunc("/timeout", timeOutHandler(1*time.Second))
	mux.HandleFunc("/close", closeHandler())
	mux.Handle("/echo", echoHandler{})
	blockedListener, err = net.Listen("tcp", ":12306")
	if assert.NoError(t, err, "listern error") {
		go func() {
			http.Serve(blockedListener, mux)
		}()

		echoListener, err = net.Listen("tcp", ":12307")
		if assert.NoError(t, err, "listern error") {
			go func() {
				http.Serve(echoListener, echoHandler{})
			}()
		}
	}
}

func stopMockServers() {
	echoListener.Close()
	blockedListener.Close()
}
