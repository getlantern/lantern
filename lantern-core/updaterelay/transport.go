package updaterelay

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/getlantern/radiance/bypass"
	"github.com/getlantern/radiance/kindling/fronted"
)

const (
	directHeaderTimeout  = 5 * time.Second
	frontedHeaderTimeout = 45 * time.Second
	idleTimeout          = time.Minute
)

// newTransport creates a transport independent of VPN startup. The caller must
// call the returned cleanup function to stop its background work.
func newTransport(ctx context.Context, cacheDir string) (http.RoundTripper, func(), error) {
	if err := os.MkdirAll(cacheDir, 0o700); err != nil {
		return nil, nil, err
	}
	front, err := fronted.NewFronted(ctx, filepath.Join(cacheDir, "fronted_cache.json"), io.Discard)
	if err != nil {
		return nil, nil, err
	}
	direct := http.DefaultTransport.(*http.Transport).Clone()
	direct.Proxy = nil
	// This dialer uses ordinary sockets when the local VPN bypass proxy is unavailable.
	direct.DialContext = bypass.DialContext
	direct.DisableCompression = true
	return &deliveryTransport{direct: direct, fronted: front.RoundTripper()}, func() {
		direct.CloseIdleConnections()
		front.Close()
	}, nil
}

type deliveryTransport struct {
	direct  http.RoundTripper
	fronted http.RoundTripper
}

// RoundTrip requires a bodyless request so direct delivery can be retried through fronting.
func (t *deliveryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	response, err := roundTrip(t.direct, req, directHeaderTimeout)
	if err == nil && response.StatusCode != http.StatusForbidden && response.StatusCode < 500 {
		return response, nil
	}
	if response != nil {
		response.Body.Close()
	}
	if req.Context().Err() != nil {
		return nil, req.Context().Err()
	}
	slog.Info("Update request using fronting", "host", req.URL.Host, "path", req.URL.Path)
	return roundTrip(t.fronted, req, frontedHeaderTimeout)
}

// roundTrip limits the wait for headers; the response body owns cancellation
// after that so a slow installer download can outlive the header timeout.
func roundTrip(transport http.RoundTripper, req *http.Request, timeout time.Duration) (*http.Response, error) {
	ctx, cancel := context.WithCancel(req.Context())
	timer := time.AfterFunc(timeout, cancel)
	response, err := transport.RoundTrip(req.Clone(ctx))
	if !timer.Stop() {
		cancel()
		if response != nil {
			response.Body.Close()
		}
		err = context.DeadlineExceeded
	}
	if err != nil {
		cancel()
		return nil, err
	}
	response.Body = &downloadBody{ReadCloser: response.Body, cancel: cancel}
	return response, nil
}

type downloadBody struct {
	io.ReadCloser
	cancel context.CancelFunc
}

func (b *downloadBody) Read(p []byte) (int, error) {
	// Bound a stalled read without imposing a total deadline on a slow download.
	timer := time.AfterFunc(idleTimeout, b.cancel)
	n, err := b.ReadCloser.Read(p)
	if !timer.Stop() {
		err = context.DeadlineExceeded
	}
	return n, err
}

func (b *downloadBody) Close() error {
	b.cancel()
	return b.ReadCloser.Close()
}

func reportFailure(stage string, err error) {
	if !errors.Is(err, context.Canceled) {
		slog.Warn("Desktop update delivery failed", "stage", stage, "error", err)
	}
}
