package enproxy

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCustomHeaders(t *testing.T) {

	proxy := &Proxy{}

	w := httptest.NewRecorder()

	req, err := http.NewRequest("GET", "http://example.com/foo", nil)
	if err != nil {
		t.Fatal(err)
	}

	xff := "7.7.7.7"
	req.Header.Set("X-Forwarded-For", xff)

	ipc := "US"
	req.Header.Set("Cf-Ipcountry", ipc)

	proxy.ServeHTTP(w, req)

	ip := w.Header().Get("Lantern-IP")
	country := w.Header().Get("Lantern-Country")

	log.Debugf("Testing IP: %v", ip)
	log.Debugf("Testing country: %v", country)
	if ip != xff {
		t.Fatalf("Unexpected ip: %v", ip)
	}
	if country != ipc {
		t.Fatalf("Unexpected country: %v", country)
	}
}
