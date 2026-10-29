package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPublicIP(t *testing.T) {
	for _, test := range []struct {
		name   string
		status int
		body   string
		want   string
	}{
		{"ipv4", http.StatusOK, "192.0.2.1\n", "192.0.2.1"},
		{"error status", http.StatusServiceUnavailable, "192.0.2.1", ""},
		{"invalid body", http.StatusOK, "not an IP", ""},
		{"ipv6", http.StatusOK, "2001:db8::1", ""},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(test.status)
				_, _ = w.Write([]byte(test.body))
			}))
			defer server.Close()
			got, err := publicIP(context.Background(), server.URL)
			if got != test.want || (err != nil) != (test.want == "") {
				t.Fatalf("publicIP = %q, %v; want %q", got, err, test.want)
			}
		})
	}
}

func TestPublicIPCanceled(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := publicIP(ctx, "http://127.0.0.1:1"); err == nil {
		t.Fatal("canceled request succeeded")
	}
}
