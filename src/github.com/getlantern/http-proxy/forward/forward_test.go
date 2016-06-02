package forward

import (
	"errors"
	"net/http"
	"testing"

	"github.com/getlantern/http-proxy/filters"

	"github.com/stretchr/testify/assert"
)

type mockRT struct {
	roundTrip func(*http.Request) (*http.Response, error)
}

func (m mockRT) RoundTrip(r *http.Request) (*http.Response, error) {
	return m.roundTrip(r)
}

type emptyRW struct {
}

func (m emptyRW) Header() http.Header {
	return http.Header{}
}

func (m emptyRW) Write([]byte) (int, error) {
	return 0, nil
}

func (m emptyRW) WriteHeader(int) {
}

// Regression for https://github.com/getlantern/http-proxy/issues/70
// and an issue of unable to distinguish slash from %2F prior to Go 1.5.
func TestCloneRequest(t *testing.T) {
	const rawPath = "/%E4%B8%9C%E6%96%B9Project/http%3A%2F%2Fwww.site.com%2Fsomething"
	const url = "http://zh.moegirl.org" + rawPath
	rt := mockRT{func(r *http.Request) (*http.Response, error) {
		assert.Equal(t, url, r.URL.String(), "should not alter the path")
		assert.Equal(t, "zh.moegirl.org", r.Header.Get("Host"), "should have host header")
		return nil, errors.New("intentionally fail")
	}}
	fwd := filters.Join(New(&Options{RoundTripper: rt}))
	req, _ := http.NewRequest("GET", url, nil)
	fwd.ServeHTTP(emptyRW{}, req)
}
