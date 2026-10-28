package lanterncore

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"maps"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/1Password/srp"
	"github.com/alecthomas/assert/v2"
	"golang.org/x/crypto/pbkdf2"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/settings"
)

type legacyEmailTestAccount struct {
	values settings.Settings
	login  func(context.Context, string, string, int64) (*account.UserData, error)
}

func (a *legacyEmailTestAccount) Settings(context.Context) (settings.Settings, error) {
	return a.values, nil
}

func (a *legacyEmailTestAccount) LoginForAccount(ctx context.Context, email, password string, id int64) (*account.UserData, error) {
	return a.login(ctx, email, password, id)
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
	requireLegacyEmailError(t, b.complete(t.Context(), "owner@example.com", "password", "000000"), "invalid or expired verification code")
	delete(a.values, settings.TokenKey)
	requireLegacyEmailError(t, b.start(t.Context(), "owner@example.com"), "not logged in")
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
			w.WriteHeader(http.StatusServiceUnavailable)
		})
		requireLegacyEmailError(t, b.complete(t.Context(), "owner@example.com", "password", "123456"), "HTTP 503")
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
