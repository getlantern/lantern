package detour

import (
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/testify/assert"
	w "github.com/getlantern/waitforserver"
)

var (
	closeURL   string = "http://localhost:12306/close"
	timeOutURL string = "http://localhost:12306/timeout"
	echoURL    string = "http://localhost:12306/echo"
	proxiedURL string = "http://localhost:12307"

	directMsg string = "hello direct"
	detourMsg string = "hello detour"
)

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
		w.Write([]byte(directMsg))
		w.(http.Flusher).Flush()
	}
}

type echoHandler struct{ msg string }

func (e echoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(e.msg))
	w.(http.Flusher).Flush()
}

var blockedListener net.Listener
var echoListener net.Listener
var blockedServer http.Server
var echoServer http.Server

func startMockServers(t *testing.T) {
	var err error
	mux := http.NewServeMux()
	mux.HandleFunc("/timeout", timeOutHandler(1*time.Hour))
	mux.HandleFunc("/close", closeHandler())
	mux.Handle("/echo", echoHandler{directMsg})
	blockedListener, err = net.Listen("tcp", ":12306")
	if assert.NoError(t, err, "listern error") {
		go func() {
			http.Serve(blockedListener, mux)
		}()

		echoListener, err = net.Listen("tcp", ":12307")
		if assert.NoError(t, err, "listen error") {
			go func() {
				http.Serve(echoListener, echoHandler{detourMsg})
			}()
		}
	}
	err = w.WaitForServer("tcp", ":12306", 2*time.Second)
	assert.NoError(t, err, "server not started")
	err = w.WaitForServer("tcp", ":12307", 2*time.Second)
	assert.NoError(t, err, "server not started")
}

func stopMockServers() {
	echoListener.Close()
	blockedListener.Close()
}
