package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
	"strings"
	"testing"
)

type serverURLImporterFunc func(context.Context, []string, bool) ([]string, error)

func (f serverURLImporterFunc) AddServersByURL(ctx context.Context, urls []string, skipCertVerification bool) ([]string, error) {
	return f(ctx, urls, skipCertVerification)
}

func TestAddServersByURLIgnoresCertificateBypass(t *testing.T) {
	for _, tt := range []struct {
		name           string
		skipValidation bool
	}{
		{name: "validation requested", skipValidation: false},
		{name: "legacy bypass requested", skipValidation: true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			ctx := t.Context()
			payload := "vless://test@example.com:443?security=tls, \thysteria2://test@example.org:443"
			wantURLs := []string{payload}
			wantTags := []string{"server-one", "server-two"}
			calls := 0
			lc := &LanternCore{
				ctx: ctx,
				serverImporter: serverURLImporterFunc(func(gotCtx context.Context, urls []string, skipCertVerification bool) ([]string, error) {
					calls++
					if gotCtx != ctx {
						t.Error("IPC client received a different context")
					}
					if !slices.Equal(urls, wantURLs) {
						t.Errorf("IPC URLs = %q, want %q", urls, wantURLs)
					}
					if skipCertVerification {
						t.Error("IPC client was asked to skip certificate verification")
					}
					return wantTags, nil
				}),
			}

			data, err := lc.AddServersByURL("  "+payload+"\n", tt.skipValidation)
			if err != nil {
				t.Fatal(err)
			}
			if calls != 1 {
				t.Fatalf("IPC calls = %d, want 1", calls)
			}
			var tags []string
			if err := json.Unmarshal(data, &tags); err != nil {
				t.Fatalf("decode server tags: %v", err)
			}
			if !slices.Equal(tags, wantTags) {
				t.Errorf("server tags = %q, want %q", tags, wantTags)
			}
		})
	}
}

func TestAddServersByURLPropagatesError(t *testing.T) {
	wantErr := errors.New("certificate verification failed")
	lc := &LanternCore{
		ctx: t.Context(),
		serverImporter: serverURLImporterFunc(func(context.Context, []string, bool) ([]string, error) {
			return nil, wantErr
		}),
	}

	data, err := lc.AddServersByURL("vless://test@example.com:443?security=tls", true)
	if !errors.Is(err, wantErr) {
		t.Errorf("error = %v, want %v", err, wantErr)
	}
	if data != nil {
		t.Errorf("result = %q, want nil on failure", data)
	}
}

func TestAddServersByURLPreservesInviteHandling(t *testing.T) {
	lc := &LanternCore{
		ctx: t.Context(),
		serverImporter: serverURLImporterFunc(func(context.Context, []string, bool) ([]string, error) {
			t.Fatal("invite link was forwarded as a proxy URL")
			return nil, nil
		}),
	}
	data, err := lc.AddServersByURL(" lantern://private-server?ip=127.0.0.1&port=invalid&token=test&name=private ", true)
	if err == nil || !strings.Contains(err.Error(), `invalid port "invalid"`) {
		t.Fatalf("error = %v, want invite port validation", err)
	}
	if data != nil {
		t.Errorf("result = %q, want nil on failure", data)
	}
}

func TestAddServersByURLPreservesAccessKey(t *testing.T) {
	payload := "vless://test@example.com:443?security=tls&alpn=h2,http/1.1#private"
	lc := &LanternCore{
		ctx: t.Context(),
		serverImporter: serverURLImporterFunc(func(_ context.Context, urls []string, skip bool) ([]string, error) {
			if !slices.Equal(urls, []string{payload}) || skip {
				t.Errorf("import = %q, skip = %v", urls, skip)
			}
			return []string{"private"}, nil
		}),
	}
	if _, err := lc.AddServersByURL(payload, true); err != nil {
		t.Fatal(err)
	}
}
