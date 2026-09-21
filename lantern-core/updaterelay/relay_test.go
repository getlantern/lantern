package updaterelay

import (
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

const testArtifact = "/releases/beta/10.0.0-beta5/lantern-installer-beta.exe"

type roundTripperFunc func(*http.Request) (*http.Response, error)

func (f roundTripperFunc) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func fixtureFeed(host string) string {
	return fmt.Sprintf(`<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>809</sparkle:version><description><![CDATA[<p>Update</p>]]></description><enclosure url="https://%s%s" sparkle:edSignature="signed-by-ci" length="22" type="application/octet-stream"/></item></channel></rss>`, host, testArtifact)
}

func fixtureRelay(t *testing.T, upstream http.HandlerFunc, fallback bool) (*relay, *atomic.Int32) {
	t.Helper()
	origin := httptest.NewServer(upstream)
	t.Cleanup(origin.Close)
	target, _ := url.Parse(origin.URL)
	calls := new(atomic.Int32)
	transport := roundTripperFunc(func(req *http.Request) (*http.Response, error) {
		calls.Add(1)
		if req.URL.Scheme != "https" || req.URL.Host != "update.getlantern.org" {
			t.Errorf("unexpected upstream: %s", req.URL)
		}
		out := req.Clone(req.Context())
		out.URL.Scheme, out.URL.Host = target.Scheme, target.Host
		return origin.Client().Transport.RoundTrip(out)
	})
	var rt http.RoundTripper = transport
	if fallback {
		rt = &deliveryTransport{
			direct: roundTripperFunc(func(*http.Request) (*http.Response, error) {
				return nil, errors.New("direct access blocked")
			}),
			fronted: transport,
		}
	}
	feed, _ := parseFeedURL("https://update.getlantern.org/update/lantern/appcast.xml?channel=beta")
	r, err := startRelay(t.Context(), feed, rt)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(r.close)
	return r, calls
}

func get(t *testing.T, address string, headers http.Header) (*http.Response, []byte) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, address, nil)
	req.Header = headers
	response, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	data, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	return response, data
}

func enclosure(t *testing.T, data []byte) string {
	t.Helper()
	var feed struct {
		Version string `xml:"channel>item>version"`
		Item    struct {
			URL       string `xml:"url,attr"`
			Signature string `xml:"http://www.andymatuschak.org/xml-namespaces/sparkle edSignature,attr"`
			Length    int    `xml:"length,attr"`
		} `xml:"channel>item>enclosure"`
	}
	if err := xml.Unmarshal(data, &feed); err != nil {
		t.Fatal(err)
	}
	if feed.Version != "809" || feed.Item.Signature != "signed-by-ci" || feed.Item.Length != 22 {
		t.Fatalf("changed appcast metadata: %+v", feed)
	}
	return feed.Item.URL
}

func TestFeedAndInstallerUseFrontingWhenDirectAccessFails(t *testing.T) {
	for _, sourceHost := range []string{"update.getlantern.org", "s3.amazonaws.com/lantern.io"} {
		t.Run(sourceHost, func(t *testing.T) {
			r, calls := fixtureRelay(t, func(w http.ResponseWriter, req *http.Request) {
				if req.Header.Get("Authorization") != "" || req.Header.Get("Cookie") != "" {
					t.Error("forwarded local credentials")
				}
				if req.URL.Path == "/update/lantern/appcast.xml" {
					if req.URL.RawQuery != "channel=beta" {
						t.Error("lost update channel")
					}
					fmt.Fprint(w, fixtureFeed(sourceHost))
					return
				}
				if req.URL.Path != testArtifact {
					t.Errorf("wrong artifact: %s", req.URL)
				}
				w.Header().Set("ETag", `"release"`)
				http.ServeContent(w, req, "installer.exe", time.Time{}, strings.NewReader("signed installer bytes"))
			}, true)
			response, data := get(t, r.feedURL(), nil)
			if response.StatusCode != 200 {
				t.Fatalf("feed: %s", data)
			}
			installer := enclosure(t, data)
			if !strings.HasPrefix(installer, r.baseURL+r.prefix) {
				t.Fatalf("escaped relay: %s", installer)
			}
			response, data = get(t, installer, http.Header{"Range": {"bytes=7-"}, "If-Range": {`"release"`}, "Authorization": {"secret"}})
			if response.StatusCode != 206 || string(data) != "installer bytes" || response.Header.Get("Content-Range") != "bytes 7-21/22" {
				t.Fatalf("range response: %d %q %v", response.StatusCode, data, response.Header)
			}
			if calls.Load() != 2 {
				t.Fatalf("fronted calls = %d", calls.Load())
			}
			head, _ := http.NewRequest(http.MethodHead, installer, nil)
			response, err := http.DefaultClient.Do(head)
			if err != nil {
				t.Fatal(err)
			}
			data, err = io.ReadAll(response.Body)
			response.Body.Close()
			if err != nil || len(data) != 0 || response.ContentLength != 22 || response.Header.Get("ETag") != `"release"` {
				t.Fatalf("HEAD: %v %q %v", err, data, response.Header)
			}
			response, data = get(t, installer, http.Header{"If-None-Match": {`"release"`}})
			if response.StatusCode != http.StatusNotModified || len(data) != 0 {
				t.Fatalf("conditional request: %d %q", response.StatusCode, data)
			}
		})
	}
}

func TestRelayRejectsUnregisteredRequests(t *testing.T) {
	r, calls := fixtureRelay(t, func(http.ResponseWriter, *http.Request) { t.Error("unexpected upstream request") }, false)
	for _, suffix := range []string{"/appcast.xml", "/wrong/appcast.xml", r.prefix + "arbitrary.exe", r.prefix + "http://evil.example"} {
		response, _ := get(t, r.baseURL+suffix, nil)
		if response.StatusCode != 404 {
			t.Errorf("%s: %d", suffix, response.StatusCode)
		}
	}
	req, _ := http.NewRequest(http.MethodGet, r.feedURL(), nil)
	req.Host = "evil.example"
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 404 || calls.Load() != 0 {
		t.Fatal("accepted untrusted Host")
	}
	request, _ := http.NewRequest(http.MethodPost, r.feedURL(), nil)
	response, err = http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 405 {
		t.Fatalf("POST: %d", response.StatusCode)
	}
}

func TestFeedRejectsInvalidContentAndOrigins(t *testing.T) {
	for _, body := range []string{"", "<html>challenge</html>", "<rss><", strings.Repeat("x", maxFeedSize+1),
		fixtureFeed("evil.example"), fixtureFeed("s3.amazonaws.com/other-bucket"),
		strings.Replace(fixtureFeed("update.getlantern.org"), "https:", "http:", 1)} {
		r, _ := fixtureRelay(t, func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, body) }, false)
		response, _ := get(t, r.feedURL(), nil)
		if response.StatusCode != 502 {
			t.Errorf("invalid feed returned %d", response.StatusCode)
		}
	}
}

func TestInstallerRedirectCannotEscapeToS3(t *testing.T) {
	r, _ := fixtureRelay(t, func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/update/lantern/appcast.xml" {
			fmt.Fprint(w, fixtureFeed("update.getlantern.org"))
			return
		}
		http.Redirect(w, req, "https://s3.amazonaws.com/lantern.io"+testArtifact, http.StatusTemporaryRedirect)
	}, false)
	_, feed := get(t, r.feedURL(), nil)
	response, _ := get(t, enclosure(t, feed), nil)
	if response.StatusCode != 502 || response.Header.Get("Location") != "" {
		t.Fatal("redirect escaped relay")
	}
}

func TestFeedRefreshKeepsPreviouslyOfferedInstallers(t *testing.T) {
	var refreshed atomic.Bool
	r, _ := fixtureRelay(t, func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/update/lantern/appcast.xml" {
			feed := fixtureFeed("update.getlantern.org")
			if refreshed.Load() {
				feed = strings.ReplaceAll(feed, "10.0.0-beta5", "10.0.0-beta6")
			}
			fmt.Fprint(w, feed)
			return
		}
		fmt.Fprint(w, req.URL.Path)
	}, false)
	_, originalFeed := get(t, r.feedURL(), nil)
	originalInstaller := enclosure(t, originalFeed)
	refreshed.Store(true)
	_, refreshedFeed := get(t, r.feedURL(), nil)
	if enclosure(t, refreshedFeed) == originalInstaller {
		t.Fatal("feed did not change")
	}
	response, data := get(t, originalInstaller, nil)
	if response.StatusCode != http.StatusOK || string(data) != testArtifact {
		t.Fatalf("previously offered installer: %d %q", response.StatusCode, data)
	}
}

func TestInstallerStreamsAndCancels(t *testing.T) {
	cancelled := make(chan struct{})
	r, _ := fixtureRelay(t, func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/update/lantern/appcast.xml" {
			fmt.Fprint(w, fixtureFeed("update.getlantern.org"))
			return
		}
		fmt.Fprint(w, "first chunk")
		w.(http.Flusher).Flush()
		<-req.Context().Done()
		close(cancelled)
	}, false)
	_, feed := get(t, r.feedURL(), nil)
	ctx, cancel := context.WithCancel(t.Context())
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, enclosure(t, feed), nil)
	response, err := (&http.Client{Timeout: 3 * time.Second}).Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	data := make([]byte, 11)
	if _, err := io.ReadFull(response.Body, data); err != nil || string(data) != "first chunk" {
		t.Fatalf("stream: %q %v", data, err)
	}
	cancel()
	select {
	case <-cancelled:
	case <-time.After(2 * time.Second):
		t.Fatal("upstream not cancelled")
	}
}

func TestDirectHeaderTimeoutDoesNotLimitResponseBody(t *testing.T) {
	ctxDone := make(chan struct{})
	rt := roundTripperFunc(func(req *http.Request) (*http.Response, error) {
		go func() { <-req.Context().Done(); close(ctxDone) }()
		return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader("data"))}, nil
	})
	req, _ := http.NewRequest(http.MethodGet, "https://update.getlantern.org", nil)
	response, err := roundTrip(rt, req, 10*time.Millisecond)
	if err != nil {
		t.Fatal(err)
	}
	time.Sleep(20 * time.Millisecond)
	select {
	case <-ctxDone:
		t.Fatal("header timeout cancelled body")
	default:
	}
	response.Body.Close()
	select {
	case <-ctxDone:
	case <-time.After(time.Second):
		t.Fatal("body close did not cancel")
	}
}

func TestHeaderTimeoutCancelsStalledRequests(t *testing.T) {
	rt := roundTripperFunc(func(req *http.Request) (*http.Response, error) {
		<-req.Context().Done()
		return nil, req.Context().Err()
	})
	req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, "https://update.getlantern.org", nil)
	if _, err := roundTrip(rt, req, 10*time.Millisecond); err == nil {
		t.Fatal("stalled request succeeded")
	}
}

func TestDeliveryFallsBackOnRejectionButPreservesOriginResults(t *testing.T) {
	for _, status := range []int{http.StatusOK, http.StatusPartialContent, http.StatusNotFound, http.StatusForbidden, http.StatusServiceUnavailable} {
		t.Run(fmt.Sprint(status), func(t *testing.T) {
			frontedCalls := 0
			transport := &deliveryTransport{
				direct: roundTripperFunc(func(*http.Request) (*http.Response, error) {
					return &http.Response{StatusCode: status, Body: io.NopCloser(strings.NewReader("direct"))}, nil
				}),
				fronted: roundTripperFunc(func(*http.Request) (*http.Response, error) {
					frontedCalls++
					return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader("fronted"))}, nil
				}),
			}
			req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, "https://update.getlantern.org", nil)
			response, err := transport.RoundTrip(req)
			if err != nil {
				t.Fatal(err)
			}
			response.Body.Close()
			wantFallback := status == http.StatusForbidden || status >= 500
			if (frontedCalls == 1) != wantFallback || (!wantFallback && response.StatusCode != status) {
				t.Fatalf("status=%d fronted calls=%d", response.StatusCode, frontedCalls)
			}
		})
	}
}

func TestFeedURLValidation(t *testing.T) {
	for _, input := range []string{"http://update.getlantern.org/update/lantern/appcast.xml?channel=beta",
		"https://evil.example/update/lantern/appcast.xml?channel=beta", "https://update.getlantern.org/update/lantern/appcast.xml?channel=other",
		"https://user@update.getlantern.org/update/lantern/appcast.xml?channel=beta"} {
		if _, err := parseFeedURL(input); err == nil {
			t.Errorf("accepted %s", input)
		}
	}
}
