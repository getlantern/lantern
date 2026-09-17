// Package updaterelay serves native desktop updaters without depending on daemon IPC.
package updaterelay

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"path"
	"strings"
	"sync"
	"time"
)

const maxFeedSize = 2 << 20

var service struct {
	sync.Mutex
	relay *relay
}

// Start returns a loopback feed URL, reusing the running relay for the same feed.
func Start(cacheDir, feedURL string) (string, error) {
	service.Lock()
	defer service.Unlock()
	if service.relay != nil {
		if service.relay.feed.String() != feedURL {
			return "", errors.New("update relay is already serving a different feed")
		}
		return service.relay.feedURL(), nil
	}
	feed, err := parseFeedURL(feedURL)
	if err != nil {
		return "", err
	}
	ctx, cancel := context.WithCancel(context.Background())
	transport, closeTransport, err := newTransport(ctx, cacheDir)
	if err != nil {
		cancel()
		return "", fmt.Errorf("initialize update transport: %w", err)
	}
	r, err := startRelay(ctx, feed, transport)
	if err != nil {
		cancel()
		closeTransport()
		return "", err
	}
	r.closeTransport = func() { cancel(); closeTransport() }
	service.relay = r
	return r.feedURL(), nil
}

// Stop cancels active downloads and releases the relay's listener and transports.
func Stop() {
	service.Lock()
	defer service.Unlock()
	if service.relay != nil {
		service.relay.close()
		service.relay = nil
	}
}

type relay struct {
	feed           *url.URL
	baseURL        string
	prefix         string
	server         *http.Server
	client         *http.Client
	closeTransport func()
	mu             sync.RWMutex
	artifacts      map[string]*url.URL
}

func parseFeedURL(raw string) (*url.URL, error) {
	u, err := url.Parse(raw)
	if err != nil {
		return nil, err
	}
	if u.Scheme != "https" || u.User != nil || u.Fragment != "" || u.RawPath != "" ||
		(u.Host != "update.getlantern.org" && u.Host != "update.staging.iantem.io") ||
		u.Path != "/update/lantern/appcast.xml" ||
		(u.RawQuery != "channel=stable" && u.RawQuery != "channel=beta") {
		return nil, errors.New("unsupported update feed")
	}
	return u, nil
}

func startRelay(ctx context.Context, feed *url.URL, transport http.RoundTripper) (*relay, error) {
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return nil, err
	}
	r := &relay{
		feed: feed, baseURL: "http://" + listener.Addr().String(),
		prefix: "/" + rand.Text() + "/", artifacts: make(map[string]*url.URL),
	}
	r.client = &http.Client{
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 5 || !r.allowedRedirect(req.URL, via[0].URL) {
				return errors.New("unsupported update redirect")
			}
			return nil
		},
	}
	r.server = &http.Server{
		Handler: r, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: time.Minute,
		MaxHeaderBytes: 16 << 10,
		BaseContext:    func(net.Listener) context.Context { return ctx },
	}
	go func() {
		if err := r.server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			reportFailure("relay", err)
		}
	}()
	return r, nil
}

func (r *relay) feedURL() string { return r.baseURL + r.prefix + "appcast.xml" }

func (r *relay) close() {
	r.server.Close()
	if r.closeTransport != nil {
		r.closeTransport()
	}
}

func (r *relay) ServeHTTP(w http.ResponseWriter, request *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if request.Host != strings.TrimPrefix(r.baseURL, "http://") ||
		!strings.HasPrefix(request.URL.Path, r.prefix) || request.URL.RawPath != "" {
		http.NotFound(w, request)
		return
	}
	if request.Method != http.MethodGet && request.Method != http.MethodHead {
		w.Header().Set("Allow", "GET, HEAD")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if request.URL.Path == r.prefix+"appcast.xml" {
		r.serveFeed(w, request)
		return
	}
	r.mu.RLock()
	artifact := r.artifacts[request.URL.Path]
	r.mu.RUnlock()
	if artifact == nil || request.URL.RawQuery != "" {
		http.NotFound(w, request)
		return
	}
	proxy := &httputil.ReverseProxy{
		Rewrite: func(p *httputil.ProxyRequest) {
			target := *artifact
			p.Out.URL = &target
			p.Out.Host = target.Host
			p.Out.RequestURI = ""
			p.Out.Body = nil
			p.Out.ContentLength = 0
			p.Out.TransferEncoding = nil
			p.Out.Trailer = nil
			p.Out.Header = updateHeaders()
			for _, header := range []string{"Range", "If-Range", "If-None-Match", "If-Modified-Since"} {
				p.Out.Header[header] = p.In.Header.Values(header)
			}
		},
		Transport: relayTransport{r.client}, FlushInterval: 100 * time.Millisecond,
		ModifyResponse: func(response *http.Response) error {
			if response.StatusCode >= 300 && response.StatusCode < 400 && response.StatusCode != http.StatusNotModified {
				return errors.New("unexpected update redirect")
			}
			response.Header.Del("Set-Cookie")
			response.Header.Set("Cache-Control", "no-store")
			return nil
		},
		ErrorHandler: func(w http.ResponseWriter, _ *http.Request, err error) {
			reportFailure("installer", err)
			http.Error(w, "update download failed", http.StatusBadGateway)
		},
	}
	proxy.ServeHTTP(w, request)
}

func updateHeaders() http.Header {
	return http.Header{"User-Agent": {"Lantern-Update-Check/1.0"}, "Accept-Encoding": {"identity"}}
}

type relayTransport struct{ client *http.Client }

func (t relayTransport) RoundTrip(req *http.Request) (*http.Response, error) { return t.client.Do(req) }

func (r *relay) serveFeed(w http.ResponseWriter, request *http.Request) {
	ctx, cancel := context.WithTimeout(request.Context(), time.Minute)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, r.feed.String(), nil)
	req.Header = updateHeaders()
	response, err := r.client.Do(req)
	if err != nil {
		r.feedFailure(w, err)
		return
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		r.feedFailure(w, fmt.Errorf("feed returned HTTP %d", response.StatusCode))
		return
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, maxFeedSize+1))
	if err == nil && len(data) > maxFeedSize {
		err = errors.New("update feed exceeds size limit")
	}
	if err == nil {
		data, err = r.rewriteFeed(data)
	}
	if err != nil {
		r.feedFailure(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.Header().Set("Content-Length", fmt.Sprint(len(data)))
	if request.Method != http.MethodHead {
		_, _ = w.Write(data)
	}
}

func (r *relay) feedFailure(w http.ResponseWriter, err error) {
	reportFailure("feed", err)
	http.Error(w, "update feed unavailable", http.StatusBadGateway)
}

func (r *relay) rewriteFeed(data []byte) ([]byte, error) {
	decoder := xml.NewDecoder(bytes.NewReader(data))
	var output bytes.Buffer
	encoder := xml.NewEncoder(&output)
	artifacts := make(map[string]*url.URL)
	rootSeen := false
	for {
		token, err := decoder.Token()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("decode update feed: %w", err)
		}
		if element, ok := token.(xml.StartElement); ok {
			if !rootSeen {
				if element.Name.Local != "rss" {
					return nil, errors.New("response is not an appcast")
				}
				rootSeen = true
			}
			if element.Name.Local == "enclosure" {
				for i, attribute := range element.Attr {
					if attribute.Name.Local != "url" || attribute.Name.Space != "" {
						continue
					}
					target, err := r.artifactURL(attribute.Value)
					if err != nil {
						return nil, err
					}
					digest := sha256.Sum256([]byte(target.String()))
					localPath := r.prefix + hex.EncodeToString(digest[:]) + "/" + path.Base(target.Path)
					artifacts[localPath] = target
					element.Attr[i].Value = r.baseURL + localPath
				}
			}
			token = element
		}
		if err := encoder.EncodeToken(token); err != nil {
			return nil, err
		}
	}
	if !rootSeen {
		return nil, errors.New("empty appcast")
	}
	if err := encoder.Close(); err != nil {
		return nil, err
	}
	r.mu.Lock()
	r.artifacts = artifacts
	r.mu.Unlock()
	return output.Bytes(), nil
}

func (r *relay) artifactURL(raw string) (*url.URL, error) {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Fragment != "" || u.RawQuery != "" || u.RawPath != "" {
		return nil, errors.New("unsupported installer URL")
	}
	if u.Host == "s3.amazonaws.com" || u.Host == "s3.us-east-1.amazonaws.com" {
		p, ok := strings.CutPrefix(u.Path, "/lantern.io/releases/")
		if !ok {
			return nil, errors.New("unsupported installer bucket")
		}
		u.Host, u.Path = r.feed.Host, "/releases/"+p
	}
	if u.Host == r.feed.Host && strings.HasPrefix(u.Path, "/releases/") && path.Clean(u.Path) == u.Path &&
		(path.Ext(u.Path) == ".dmg" || path.Ext(u.Path) == ".exe") {
		return u, nil
	}
	if r.feed.Host == "update.staging.iantem.io" && u.Host == "github.com" &&
		strings.HasPrefix(u.Path, "/getlantern/lantern-update-fixtures/releases/download/") {
		return u, nil
	}
	return nil, errors.New("unsupported installer origin")
}

func (r *relay) allowedRedirect(target, original *url.URL) bool {
	if target.Scheme != "https" || target.User != nil || target.Fragment != "" || target.RawPath != "" {
		return false
	}
	if target.Host == original.Host && target.Path == original.Path && target.RawQuery == original.RawQuery {
		return true
	}
	return r.feed.Host == "update.staging.iantem.io" && original.Host == "github.com" &&
		target.Host == "release-assets.githubusercontent.com"
}
