package eventsource

import (
	"net"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"testing"
	"time"
)

type CloseNotifiterRecorder struct {
	*httptest.ResponseRecorder
}

func NewCloseNotifierRecorder() *CloseNotifiterRecorder {
	recorder := httptest.NewRecorder()
	myRecorder := new(CloseNotifiterRecorder)
	myRecorder.ResponseRecorder = recorder
	return myRecorder
}

func (r CloseNotifiterRecorder) CloseNotify() <-chan bool {
	channel := make(chan bool)
	return channel
}

func TestServeHttpWritesTheProperHeaders(t *testing.T) {
	req, err := http.NewRequest("GET", "http://example.com/foo", nil)
	if err != nil {
		t.Errorf("Failed to create request")
	}

	recorder := NewCloseNotifierRecorder()

	eventHandler := func(es *Conn) {}

	httpHandler := Handler(eventHandler)

	httpHandler.ServeHTTP(recorder, req)

	if recorder.Header().Get("Content-Type") != "text/event-stream" {
		t.Errorf("Content-Type header not set to text/event-stream")
	}

	if recorder.Header().Get("Cache-Control") != "no-cache" {
		t.Errorf("Cache-Control header not set to no-cache")
	}

	if recorder.Header().Get("Connection") != "keep-alive" {
		t.Errorf("Connection header not set to keep-alive")
	}

	if recorder.Header().Get("Transfer-Encoding") != "chunked" {
		t.Errorf("Transfer-Encoding header not set to chunked")
	}
}

func TestServeHttpSetsResponseToOK(t *testing.T) {
	req, err := http.NewRequest("GET", "http://example.com/foo", nil)
	if err != nil {
		t.Errorf("Failed to create request")
	}

	recorder := NewCloseNotifierRecorder()

	eventHandler := func(es *Conn) {}

	httpHandler := Handler(eventHandler)

	httpHandler.ServeHTTP(recorder, req)

	if recorder.Code != 200 {
		t.Errorf("Response was not a 200")
	}
}

func TestServeHttpFlushes(t *testing.T) {
	req, err := http.NewRequest("GET", "http://example.com/foo", nil)
	if err != nil {
		t.Errorf("Failed to create request")
	}

	recorder := NewCloseNotifierRecorder()

	eventHandler := func(es *Conn) {}

	httpHandler := Handler(eventHandler)

	httpHandler.ServeHTTP(recorder, req)

	if !recorder.Flushed {
		t.Errorf("Not flushed")
	}
}

func TestAllowsNotificationThatClientWentAway(t *testing.T) {
	clientWentAway := make(chan bool)
	eventHandler := func(es *Conn) {
		clientWentAway <- <-es.CloseNotify()
	}

	server := httptest.NewServer(Handler(eventHandler))
	defer server.Close()

	tcpConn, err := net.Dial("tcp", server.Listener.Addr().String())
	if err != nil {
		t.Errorf("Error opening client connection: %s", err)
	}

	conn := httputil.NewClientConn(tcpConn, nil)
	req, err := http.NewRequest("GET", "/", nil)
	if err != nil {
		t.Errorf("Error creating request: %s", err)
	}

	err = conn.Write(req)
	if err != nil {
		t.Errorf("Error writing request: %s", err)
	}

	err = conn.Close()
	if err != nil {
		t.Errorf("Could not close client connection: %s", err)
	}

	select {
	case <-clientWentAway:
		// test worked
	case <-time.After(1 * time.Second):
		t.Errorf("Never told that the client went away.")
	}

}

func TestConnWritingAMessage(t *testing.T) {
	recorder := httptest.NewRecorder()
	connection := &Conn{recorder, recorder, NewCloseNotifierRecorder()}

	connection.Write("Hello World")

	expectedBody := "data: Hello World\n\n"

	switch recorder.Body.String() {
	case expectedBody:
		// body is equal so no need to do anything
	default:
		t.Errorf("Body (%s) did not match expectation (%s).", recorder.Body.String(), expectedBody)
	}

	if !recorder.Flushed {
		t.Errorf("Writer did not get flushed.")
	}
}
