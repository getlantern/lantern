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
	directTimeout = 5 * time.Second
	headerTimeout = 45 * time.Second
	idleTimeout   = time.Minute
)

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

func (t *deliveryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	response, err := roundTrip(t.direct, req, directTimeout)
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
	return roundTrip(t.fronted, req, headerTimeout)
}

func roundTrip(transport http.RoundTripper, req *http.Request, timeout time.Duration) (*http.Response, error) {
	ctx, cancel := context.WithCancel(req.Context())
	timer := time.AfterFunc(timeout, cancel)
	response, err := transport.RoundTrip(req.Clone(ctx))
	if !timer.Stop() && err == nil {
		response.Body.Close()
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
	if !timer.Stop() && err == nil {
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
