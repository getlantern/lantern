package detour

import (
	"net/http"
	"net/http/httptest"
	"time"
)

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
		if _, err := conn.Write([]byte(msg)); err != nil {
			log.Debugf("Unable to write to connection: %v", err)
		}
		if err := conn.Close(); err != nil {
			log.Debugf("Unable to close connection: %v", err)
		}
	}
}

func (m *mockHandler) Msg(msg string) {
	m.writer = func(w http.ResponseWriter) {
		if _, err := w.Write([]byte(msg)); err != nil {
			log.Debugf("Unable to write to connection: %v", err)
		}
		w.(http.Flusher).Flush()
	}
}

func (m *mockHandler) Timeout(d time.Duration, msg string) {
	m.writer = func(w http.ResponseWriter) {
		time.Sleep(d)
		if _, err := w.Write([]byte(msg)); err != nil {
			log.Debugf("Unable to write to connection: %v", err)
		}
		w.(http.Flusher).Flush()
	}
}

func newMockServer(msg string) (string, *mockHandler) {
	m := mockHandler{nil}
	m.Msg(msg)
	s := httptest.NewServer(&m)
	servers = append(servers, s)
	return s.URL, &m
}

func stopMockServers() {
	for _, s := range servers {
		s.CloseClientConnections()
		s.Close()
	}
}
