package detour

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

var (
	closeURL, timeOutURL, echoURL, proxiedURL string
	directMsg                                 string = "hello direct"
	detourMsg                                 string = "hello detour"
)

func closeHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		hj := w.(http.Hijacker)
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

var servers []*httptest.Server

func startMockServers(t *testing.T) {
	servers = []*httptest.Server{
		httptest.NewServer(closeHandler()),
		httptest.NewServer(timeOutHandler(1 * time.Second)),
		httptest.NewServer(echoHandler{directMsg}),
		httptest.NewServer(echoHandler{detourMsg}),
	}
	closeURL = servers[0].URL
	timeOutURL = servers[1].URL
	echoURL = servers[2].URL
	proxiedURL = servers[3].URL
}

func stopMockServers() {
	for _, s := range servers {
		s.CloseClientConnections()
		s.Close()
	}
}
