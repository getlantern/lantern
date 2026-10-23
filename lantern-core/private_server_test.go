package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"slices"
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
			wantURLs := []string{
				"vless://test@example.com:443?security=tls",
				"hysteria2://test@example.org:443",
			}
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

			data, err := lc.AddServersByURL("  "+wantURLs[0]+", \t"+wantURLs[1]+"\n", tt.skipValidation)
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
