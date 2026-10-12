package updaterelay

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"testing"
	"testing/synctest"
	"time"
)

type readCloserFunc func([]byte) (int, error)

func (f readCloserFunc) Read(p []byte) (int, error) { return f(p) }
func (readCloserFunc) Close() error                 { return nil }

func downloadTestBody(t *testing.T, ctx context.Context, read func(context.Context, []byte) (int, error)) *downloadBody {
	t.Helper()
	transport := roundTripperFunc(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusOK,
			Body: readCloserFunc(func(p []byte) (int, error) {
				return read(req.Context(), p)
			}),
		}, nil
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://update.getlantern.org", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := roundTrip(transport, req, directHeaderTimeout)
	if err != nil {
		t.Fatal(err)
	}
	body := response.Body.(*downloadBody)
	t.Cleanup(func() { body.Close() })
	return body
}

func TestDownloadBodyPreservesReadResultsAfterIdleTimeout(t *testing.T) {
	unrelated := errors.New("upstream failed")
	for _, test := range []struct {
		name string
		err  error
		want error
	}{
		{"progress", nil, nil},
		{"eof", io.EOF, io.EOF},
		{"unrelated error", unrelated, unrelated},
		{"cancellation", context.Canceled, context.DeadlineExceeded},
		{"wrapped cancellation", fmt.Errorf("body read: %w", context.Canceled), context.DeadlineExceeded},
	} {
		t.Run(test.name, func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				body := downloadTestBody(t, t.Context(), func(ctx context.Context, p []byte) (int, error) {
					<-ctx.Done()
					return copy(p, "bytes"), test.err
				})
				p := make([]byte, 16)
				n, err := body.Read(p)
				if n != 5 || string(p[:n]) != "bytes" || err != test.want {
					t.Fatalf("read = (%d, %v), data %q; want (5, %v)", n, err, p[:n], test.want)
				}
			})
		})
	}
}

func TestDownloadBodyRemembersTimeoutForLaterRead(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		reads := 0
		body := downloadTestBody(t, t.Context(), func(ctx context.Context, p []byte) (int, error) {
			reads++
			<-ctx.Done()
			if reads == 1 {
				// A transport can return buffered bytes before observing cancellation.
				return copy(p, "first"), nil
			}
			return copy(p, "last"), ctx.Err()
		})
		p := make([]byte, 16)
		if n, err := body.Read(p); n != 5 || string(p[:n]) != "first" || err != nil {
			t.Fatalf("first read = (%d, %v), data %q", n, err, p[:n])
		}
		if n, err := body.Read(p); n != 4 || string(p[:n]) != "last" || !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("later read = (%d, %v), data %q", n, err, p[:n])
		}
	})
}

func TestDownloadBodyPreservesCallerCancellation(t *testing.T) {
	for _, closeBody := range []bool{false, true} {
		t.Run(fmt.Sprintf("close=%t", closeBody), func(t *testing.T) {
			synctest.Test(t, func(t *testing.T) {
				ctx, cancel := context.WithCancel(t.Context())
				defer cancel()
				body := downloadTestBody(t, ctx, func(ctx context.Context, p []byte) (int, error) {
					<-ctx.Done()
					// Let the idle timer fire too: the first cancellation still owns
					// the cause even when the underlying read takes time to unwind.
					time.Sleep(2 * idleTimeout)
					return copy(p, "bytes"), ctx.Err()
				})
				time.AfterFunc(idleTimeout/2, func() {
					if closeBody {
						body.Close()
					} else {
						cancel()
					}
				})
				p := make([]byte, 16)
				if n, err := body.Read(p); n != 5 || string(p[:n]) != "bytes" || err != context.Canceled {
					t.Fatalf("cancelled read = (%d, %v), data %q", n, err, p[:n])
				}
			})
		})
	}
}

func TestDownloadBodyCompletedReadsDoNotCancelDownload(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		body := downloadTestBody(t, t.Context(), func(ctx context.Context, p []byte) (int, error) {
			if err := ctx.Err(); err != nil {
				return 0, err
			}
			return copy(p, "bytes"), nil
		})
		p := make([]byte, 16)
		for range 3 {
			if n, err := body.Read(p); n != 5 || string(p[:n]) != "bytes" || err != nil {
				t.Fatalf("read = (%d, %v), data %q", n, err, p[:n])
			}
			// No active read means no idle timer, even during a slow consumer.
			time.Sleep(2 * idleTimeout)
			if err := body.ctx.Err(); err != nil {
				t.Fatalf("completed read cancelled download: %v", err)
			}
		}
	})
}

func TestDownloadBodyCompletionRacesIdleTimeout(t *testing.T) {
	synctest.Test(t, func(t *testing.T) {
		for range 20 {
			body := downloadTestBody(t, t.Context(), func(_ context.Context, p []byte) (int, error) {
				// Both the reader and idle timer become runnable at the deadline.
				time.Sleep(idleTimeout)
				return copy(p, "bytes"), nil
			})
			p := make([]byte, 16)
			if n, err := body.Read(p); n != 5 || string(p[:n]) != "bytes" || err != nil {
				t.Fatalf("boundary read = (%d, %v), data %q", n, err, p[:n])
			}
			cancelled := body.ctx.Err() != nil
			synctest.Wait()
			if !cancelled && body.ctx.Err() != nil {
				t.Fatal("late timer callback cancelled a completed read")
			}
			body.Close()
		}
	})
}
