package detour

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

var (
	proxiedURL string
	directMsg  string = "hello direct"
	detourMsg  string = "hello detour"
)

type echoHandler struct{ msg string }

func (e echoHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte(e.msg))
	w.(http.Flusher).Flush()
}

var iranResp string = `HTTP/1.1 403 Forbidden
Connection:close

<html><head><meta http-equiv="Content-Type" content="text/html; charset=windows-1256"><title>M1-6
</title></head><body><iframe src="http://10.10.34.34?type=Invalid Site&policy=MainPolicy " style="width: 100%; height: 100%" scrolling="no" marginwidth="0" marginheight="0" frameborder="0" vspace="0" hspace="0"></iframe></body></html>Connection closed by foreign host.`

func iranRedirectHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(iranResp))
	}
}

var servers []*httptest.Server

type mockHandler struct {
	writer func(w http.ResponseWriter)
}

func (m *mockHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	m.writer(w)
}

func (m *mockHandler) Raw(msg string) {
	m.writer = func(w http.ResponseWriter) {
		conn, _, _ := w.(http.Hijacker).Hijack()
		conn.Write([]byte(msg))
		conn.Close()
	}
}

func (m *mockHandler) Msg(msg string) {
	m.writer = func(w http.ResponseWriter) {
		w.Write([]byte(msg))
		w.(http.Flusher).Flush()
	}
}

func (m *mockHandler) Timeout(d time.Duration) {
	m.writer = func(w http.ResponseWriter) {
		time.Sleep(d)
		w.Write([]byte(directMsg))
		w.(http.Flusher).Flush()
	}
}

func startMockServers(t *testing.T) (string, *mockHandler) {
	s := httptest.NewServer(echoHandler{detourMsg})
	proxiedURL = s.URL
	servers = append(servers, s)

	m := mockHandler{nil}
	s = httptest.NewServer(&m)
	servers = append(servers, s)
	return s.URL, &m
}

func stopMockServers() {

	for _, s := range servers {
		s.CloseClientConnections()
		s.Close()
	}
}
