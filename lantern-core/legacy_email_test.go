package lanterncore

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"maps"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/1Password/srp"
	"github.com/alecthomas/assert/v2"
	"golang.org/x/crypto/pbkdf2"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/settings"
)

type legacyEmailTestAccount struct {
	values      settings.Settings
	getSettings func(context.Context) (settings.Settings, error)
	login       func(context.Context, string, string, int64) (*account.UserData, error)
}

func (a *legacyEmailTestAccount) Settings(ctx context.Context) (settings.Settings, error) {
	if a.getSettings != nil {
		return a.getSettings(ctx)
	}
	return a.values, nil
}

func (a *legacyEmailTestAccount) LoginForAccount(ctx context.Context, email, password string, id int64) (*account.UserData, error) {
	return a.login(ctx, email, password, id)
}

type legacyEmailRoundTripper func(*http.Request) (*http.Response, error)

func (f legacyEmailRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	return f(r)
}

func requireLegacyEmailError(t *testing.T, err error, message string) {
	t.Helper()
	if err == nil || !strings.Contains(err.Error(), message) {
		t.Fatalf("error = %v, want message containing %q", err, message)
	}
}

func legacyEmailTestClient(t *testing.T, handler http.HandlerFunc) (legacyEmailBinder, *legacyEmailTestAccount) {
	t.Helper()
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	a := &legacyEmailTestAccount{values: settings.Settings{
		settings.UserIDKey: float64(2000000042), settings.TokenKey: "pro-token", settings.DeviceIDKey: "device",
	}, login: func(context.Context, string, string, int64) (*account.UserData, error) {
		t.Fatal("unexpected login")
		return nil, nil
	}}
	return legacyEmailBinder{account: a, http: server.Client(), authURL: server.URL, proURL: server.URL}, a
}

func TestLegacyEmailBindingRequests(t *testing.T) {
	paths := make(chan string, 2)
	b, a := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		paths <- r.URL.Path
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "2000000042", r.Header.Get(common.UserIDHeader))
		assert.Equal(t, "pro-token", r.Header.Get(common.ProTokenHeader))
		assert.Equal(t, "device", r.Header.Get(common.DeviceIDHeader))
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))
		assert.Equal(t, "application/json", r.Header.Get("Accept"))
		var request struct {
			Email       string `json:"email"`
			Code        string `json:"code"`
			NewSalt     []byte `json:"new_salt"`
			NewVerifier []byte `json:"new_verifier"`
		}
		assert.NoError(t, json.NewDecoder(r.Body).Decode(&request))
		assert.Equal(t, "owner@example.com", request.Email)
		if strings.HasSuffix(r.URL.Path, "/complete") {
			assert.Equal(t, "123456", request.Code)
			assert.Equal(t, 16, len(request.NewSalt))
			key := pbkdf2.Key([]byte("new-passwordowner@example.com"), request.NewSalt, 4096, 32, sha256.New)
			client := srp.NewSRPClient(srp.KnownGroups[srp.RFC5054Group3072], new(big.Int).SetBytes(key), nil)
			verifier, err := client.Verifier()
			assert.NoError(t, err)
			assert.Equal(t, verifier.Bytes(), request.NewVerifier)
		}
		_, _ = w.Write([]byte(`{}`))
	})
	before := maps.Clone(a.values)
	assert.NoError(t, b.start(t.Context(), " Owner@Example.COM "))
	a.login = func(_ context.Context, email, password string, id int64) (*account.UserData, error) {
		assert.Equal(t, "owner@example.com", email)
		assert.Equal(t, "new-password", password)
		assert.Equal(t, int64(2000000042), id)
		return &account.UserData{LegacyID: id, Success: true}, nil
	}
	assert.NoError(t, b.complete(t.Context(), " Owner@Example.COM ", "new-password", "123456"))
	assert.Equal(t, []string{"/users/bind_legacy_email", "/users/bind_legacy_email/complete"}, []string{<-paths, <-paths})
	assert.Equal(t, before, a.values)
}

func TestLegacyEmailBindingFailures(t *testing.T) {
	b, a := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"status":400,"msg":"invalid or expired verification code"}`))
	})
	err := b.complete(t.Context(), "owner@example.com", "password", "000000")
	requireLegacyEmailError(t, err, "received bad response: invalid or expired verification code")
	delete(a.values, settings.TokenKey)
	requireLegacyEmailError(t, b.start(t.Context(), "owner@example.com"), "not logged in")
}

func TestLegacyEmailBindingAPIErrorMessageOnly(t *testing.T) {
	for _, tc := range []struct {
		body string
		want string
	}{
		{`{"msg":"invalid email","token":"pro-token"}`, "legacy email binding: HTTP 400: received bad response: invalid email"},
		{`<html>pro-token</html>`, "legacy email binding: HTTP 400"},
	} {
		b, _ := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte(tc.body))
		})
		err := b.start(t.Context(), "owner@example.com")
		requireLegacyEmailError(t, err, tc.want)
		assert.Equal(t, tc.want, err.Error())
	}
}

func TestLegacyEmailBindingCommittedResponseRetry(t *testing.T) {
	for _, status := range []int{0, http.StatusServiceUnavailable, http.StatusForbidden} {
		t.Run(http.StatusText(status), func(t *testing.T) {
			b, a := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path == "/user-data" {
					assert.Equal(t, "2000000042", r.Header.Get(common.UserIDHeader))
					assert.Equal(t, "pro-token", r.Header.Get(common.ProTokenHeader))
					_, _ = w.Write([]byte(`{"userId":2000000042,"email":"owner@example.com"}`))
					return
				}
				if status == 0 {
					connection, _, err := w.(http.Hijacker).Hijack()
					assert.NoError(t, err)
					_ = connection.Close()
					return
				}
				w.WriteHeader(status)
			})
			a.login = func(_ context.Context, _, _ string, id int64) (*account.UserData, error) {
				return &account.UserData{LegacyID: id, Success: true}, nil
			}
			assert.NoError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"))
		})
	}
}

func TestLegacyEmailBindingReadbackMustMatchAccountAndEmail(t *testing.T) {
	for _, status := range []int{http.StatusBadRequest, http.StatusServiceUnavailable} {
		t.Run(http.StatusText(status), func(t *testing.T) {
			for _, body := range []string{
				`{"userId":999,"email":"owner@example.com"}`,
				`{"userId":2000000042,"email":"support+2000000042@getlantern.org"}`,
				`{}`,
				`{"error":"unavailable"}`,
			} {
				b, _ := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
					if r.URL.Path == "/user-data" {
						_, _ = w.Write([]byte(body))
						return
					}
					w.WriteHeader(status)
					_, _ = w.Write([]byte(`{"msg":"completion failed"}`))
				})
				err := b.complete(t.Context(), "owner@example.com", "password", "123456")
				var apiErr *legacyEmailAPIError
				assert.True(t, errors.As(err, &apiErr))
				assert.Equal(t, status, apiErr.status)
				requireLegacyEmailError(t, err, "received bad response: completion failed")
			}
		})
	}
}

func TestLegacyEmailBindingCommittedLoginRetry(t *testing.T) {
	for _, tc := range []struct {
		status     int
		loginError string
	}{
		{http.StatusBadRequest, "temporary login failure"},
		{http.StatusForbidden, "authenticated account does not match expected account"},
	} {
		t.Run(http.StatusText(tc.status), func(t *testing.T) {
			var posts atomic.Int32
			logins := 0
			b, a := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
				assert.Equal(t, "2000000042", r.Header.Get(common.UserIDHeader))
				assert.Equal(t, "pro-token", r.Header.Get(common.ProTokenHeader))
				assert.Equal(t, "device", r.Header.Get(common.DeviceIDHeader))
				if r.URL.Path == "/user-data" {
					_, _ = w.Write([]byte(`{"userId":2000000042,"email":"owner@example.com"}`))
					return
				}
				if posts.Add(1) > 1 {
					w.WriteHeader(tc.status)
					_, _ = w.Write([]byte(`{"msg":"invalid or expired verification code"}`))
				}
			})
			before := maps.Clone(a.values)
			a.login = func(_ context.Context, email, password string, id int64) (*account.UserData, error) {
				assert.Equal(t, "owner@example.com", email)
				assert.Equal(t, "password", password)
				assert.Equal(t, int64(2000000042), id)
				logins++
				if logins == 1 {
					return nil, errors.New(tc.loginError)
				}
				return &account.UserData{LegacyID: id, Success: true}, nil
			}
			requireLegacyEmailError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"), "legacy_email_bound_login_required")
			assert.Equal(t, before, a.values)
			assert.NoError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"))
			assert.Equal(t, int32(2), posts.Load())
			assert.Equal(t, 2, logins)
		})
	}
}

func TestLegacyEmailBindingTimedOutResponseUsesFreshBudgets(t *testing.T) {
	b, a := legacyEmailTestClient(t, func(http.ResponseWriter, *http.Request) {
		t.Error("unexpected network request")
	})
	b.timeout = 5 * time.Millisecond
	var identityCtx, completionCtx, recoveryCtx, loginCtx context.Context
	a.getSettings = func(ctx context.Context) (settings.Settings, error) {
		identityCtx = ctx
		return a.values, nil
	}
	b.http.Transport = legacyEmailRoundTripper(func(r *http.Request) (*http.Response, error) {
		if r.URL.Path == "/users/bind_legacy_email/complete" {
			completionCtx = r.Context()
			// The server committed the binding, but its response never arrived.
			<-r.Context().Done()
			return nil, r.Context().Err()
		}
		assert.Equal(t, "/user-data", r.URL.Path)
		recoveryCtx = r.Context()
		assert.NoError(t, recoveryCtx.Err())
		return &http.Response{StatusCode: http.StatusOK, Body: io.NopCloser(strings.NewReader(
			`{"userId":2000000042,"email":"owner@example.com"}`,
		))}, nil
	})
	a.login = func(ctx context.Context, _, _ string, id int64) (*account.UserData, error) {
		loginCtx = ctx
		assert.NoError(t, ctx.Err())
		assert.Equal(t, int64(2000000042), id)
		return &account.UserData{LegacyID: id, Success: true}, nil
	}
	assert.NoError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"))
	assert.True(t, errors.Is(completionCtx.Err(), context.DeadlineExceeded))
	var previousDeadline time.Time
	for _, ctx := range []context.Context{identityCtx, completionCtx, recoveryCtx, loginCtx} {
		deadline, ok := ctx.Deadline()
		assert.True(t, ok)
		assert.True(t, deadline.After(previousDeadline))
		previousDeadline = deadline
	}
}

func TestLegacyEmailBindingHonorsCallerCancellation(t *testing.T) {
	for _, stage := range []string{"identity", "completion", "recovery", "login"} {
		t.Run(stage, func(t *testing.T) {
			ctx, cancel := context.WithCancel(t.Context())
			defer cancel()
			b, a := legacyEmailTestClient(t, func(http.ResponseWriter, *http.Request) {
				t.Error("unexpected network request")
			})
			a.getSettings = func(ctx context.Context) (settings.Settings, error) {
				if stage == "identity" {
					cancel()
					assert.True(t, errors.Is(ctx.Err(), context.Canceled))
					return nil, ctx.Err()
				}
				return a.values, nil
			}
			b.http.Transport = legacyEmailRoundTripper(func(r *http.Request) (*http.Response, error) {
				assert.NoError(t, r.Context().Err())
				if r.URL.Path == "/users/bind_legacy_email/complete" {
					if stage == "completion" {
						cancel()
						assert.True(t, errors.Is(r.Context().Err(), context.Canceled))
						return nil, r.Context().Err()
					}
					if stage == "recovery" {
						return nil, errors.New("response lost")
					}
					return &http.Response{StatusCode: http.StatusOK, Body: http.NoBody}, nil
				}
				if stage != "recovery" {
					t.Fatal("unexpected recovery request after cancellation")
				}
				cancel()
				assert.True(t, errors.Is(r.Context().Err(), context.Canceled))
				return nil, r.Context().Err()
			})
			a.login = func(ctx context.Context, _, _ string, _ int64) (*account.UserData, error) {
				if stage != "login" {
					t.Fatal("unexpected login after cancellation")
				}
				cancel()
				assert.True(t, errors.Is(ctx.Err(), context.Canceled))
				return nil, ctx.Err()
			}
			assert.True(t, errors.Is(b.complete(ctx, "owner@example.com", "password", "123456"), context.Canceled))
		})
	}
}

func TestLegacyEmailBindingLoginFailure(t *testing.T) {
	b, a := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{}`))
	})
	a.login = func(context.Context, string, string, int64) (*account.UserData, error) {
		return nil, errors.New("account changed while signing in")
	}
	requireLegacyEmailError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"), "legacy_email_bound_login_required")
}

func TestLegacyEmailBindingRejectsRedirects(t *testing.T) {
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("credentials followed a redirect")
	}))
	defer target.Close()
	b, _ := legacyEmailTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, target.URL, http.StatusTemporaryRedirect)
	})
	requireLegacyEmailError(t, b.start(t.Context(), "owner@example.com"), "HTTP 307")
}
