//go:build !novpn

package lanterncore

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sync"
	"testing"

	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/vpn"
)

type splitTunnelTestClient struct {
	handler      *vpn.SplitTunnel
	mu           sync.Mutex
	calls        []string
	beforeRemove func()
}

func (c *splitTunnelTestClient) record(ctx context.Context, operation string) error {
	c.mu.Lock()
	c.calls = append(c.calls, operation)
	c.mu.Unlock()
	return ctx.Err()
}

func (c *splitTunnelTestClient) Settings(ctx context.Context) (settings.Settings, error) {
	if err := c.record(ctx, "settings"); err != nil {
		return nil, err
	}
	return settings.Settings{settings.SplitTunnelKey: c.handler.IsEnabled()}, nil
}

func (c *splitTunnelTestClient) SplitTunnelFilters(ctx context.Context) (vpn.SplitTunnelFilter, error) {
	if err := c.record(ctx, "read"); err != nil {
		return vpn.SplitTunnelFilter{}, err
	}
	return c.handler.Filters(), nil
}

func (c *splitTunnelTestClient) AddSplitTunnelItems(ctx context.Context, filter vpn.SplitTunnelFilter) error {
	if err := c.record(ctx, "add"); err != nil {
		return err
	}
	return c.handler.AddItems(filter)
}

func (c *splitTunnelTestClient) RemoveSplitTunnelItems(ctx context.Context, filter vpn.SplitTunnelFilter) error {
	if err := c.record(ctx, "remove"); err != nil {
		return err
	}
	if c.beforeRemove != nil {
		c.beforeRemove()
	}
	return c.handler.RemoveItems(filter)
}

func newSplitTunnelTestClient(t *testing.T, dir string) *splitTunnelTestClient {
	t.Helper()
	handler, err := vpn.NewSplitTunnelHandler(dir, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatal(err)
	}
	return &splitTunnelTestClient{handler: handler}
}

// blockSplitTunnelSave preserves the saved file while making atomic replacement fail.
func blockSplitTunnelSave(t *testing.T, dir string) func() {
	t.Helper()
	path := filepath.Join(dir, "split-tunnel.json")
	backup := path + ".saved"
	if err := os.Rename(path, backup); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(path, 0o700); err != nil {
		t.Fatal(err)
	}
	return func() {
		t.Helper()
		if err := os.Remove(path); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(backup, path); err != nil {
			t.Fatal(err)
		}
	}
}

func TestSplitTunnelPathsRetriesFailedSave(t *testing.T) {
	for _, remove := range []bool{false, true} {
		name := "add"
		if remove {
			name = "remove"
		}
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			initial := vpn.SplitTunnelFilter{Domain: []string{"example.com"}}
			if remove {
				initial.ProcessPath = []string{"game.exe"}
			}
			if err := client.handler.AddItems(initial); err != nil {
				t.Fatal(err)
			}
			paths := splitTunnelPaths{client: client}
			unblock := blockSplitTunnelSave(t, dir)
			if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{"game.exe"}}, remove); err == nil {
				t.Fatal("update succeeded while saving was blocked")
			}
			if !paths.pendingSave {
				t.Fatal("failed save was not retained for retry")
			}
			want := vpn.SplitTunnelFilter{Domain: initial.Domain}
			if !remove {
				want.ProcessPath = []string{"game.exe"}
			}
			if got := client.handler.Filters(); !slices.Equal(got.ProcessPath, want.ProcessPath) || !slices.Equal(got.Domain, want.Domain) {
				t.Fatalf("in-memory filters = %#v, want %#v", got, want)
			}
			unblock()
			if got := newSplitTunnelTestClient(t, dir).handler.Filters(); !reflect.DeepEqual(got, initial) {
				t.Fatalf("saved filters changed after failure: %#v", got)
			}
			client.calls = nil
			if _, err := paths.filters(t.Context()); err != nil {
				t.Fatal(err)
			}
			if paths.pendingSave {
				t.Fatal("successful retry left a pending save")
			}
			if !reflect.DeepEqual(client.calls, []string{"read", "remove", "read"}) {
				t.Fatalf("retry calls = %v", client.calls)
			}
			if got := newSplitTunnelTestClient(t, dir).handler.Filters(); !reflect.DeepEqual(got, want) {
				t.Fatalf("saved filters = %#v, want %#v", got, want)
			}
		})
	}
}

func TestSplitTunnelPathsPreparesEnabledConnections(t *testing.T) {
	for _, enabled := range []bool{false, true} {
		name := "disabled"
		if enabled {
			name = "enabled"
		}
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			if err := client.handler.SetEnabled(enabled); err != nil {
				t.Fatal(err)
			}
			paths := splitTunnelPaths{client: client, pendingSave: true}
			unblock := blockSplitTunnelSave(t, dir)
			err := paths.prepareConnect(t.Context())
			if (err != nil) != enabled {
				t.Fatalf("prepareConnect with enabled=%v: %v", enabled, err)
			}
			wantCalls := []string{"settings"}
			if enabled {
				wantCalls = append(wantCalls, "read", "remove")
			}
			if !reflect.DeepEqual(client.calls, wantCalls) || !paths.pendingSave {
				t.Fatalf("prepare calls=%v, pendingSave=%v", client.calls, paths.pendingSave)
			}
			unblock()
			if err := client.handler.SetEnabled(true); err != nil {
				t.Fatal(err)
			}
			if err := paths.prepareConnect(t.Context()); err != nil {
				t.Fatal(err)
			}
			if paths.pendingSave {
				t.Fatal("enabled connection did not retry the pending save")
			}
		})
	}
}

func TestSplitTunnelPathsCanceled(t *testing.T) {
	client := newSplitTunnelTestClient(t, t.TempDir())
	paths := splitTunnelPaths{client: client}
	ctx, cancel := context.WithCancel(t.Context())
	cancel()
	if err := paths.update(ctx, vpn.SplitTunnelFilter{ProcessPath: []string{"game.exe"}}, false); !errors.Is(err, context.Canceled) {
		t.Fatalf("update error = %v, want cancellation", err)
	}
	if !reflect.DeepEqual(client.calls, []string{"read"}) {
		t.Fatalf("canceled update calls = %v", client.calls)
	}
	if paths.pendingSave || len(client.handler.Filters().ProcessPath) != 0 {
		t.Fatal("canceled update changed the filter")
	}
}

func TestSplitTunnelPathsSerializesUpdates(t *testing.T) {
	client := newSplitTunnelTestClient(t, t.TempDir())
	paths := splitTunnelPaths{client: client}
	start := make(chan struct{})
	var workers sync.WaitGroup
	for range 8 {
		workers.Go(func() {
			<-start
			if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{"game.exe"}}, false); err != nil {
				t.Error(err)
			}
		})
	}
	close(start)
	workers.Wait()
	if got := client.handler.Filters().ProcessPath; !reflect.DeepEqual(got, []string{"game.exe"}) {
		t.Fatalf("concurrent updates saved duplicate paths: %v", got)
	}
}

func TestSplitTunnelPathsRemovesOrphanAliases(t *testing.T) {
	dir := t.TempDir()
	client := newSplitTunnelTestClient(t, dir)
	userPattern := `(?i)^C:\\Games\\Game\.exe$`
	orphan := `(?i)^(?P<lantern_windows_executable>)C:\\Old\\Game\.exe$`
	if err := client.handler.AddItems(vpn.SplitTunnelFilter{
		ProcessPathRegex: []string{orphan, userPattern},
	}); err != nil {
		t.Fatal(err)
	}
	paths := splitTunnelPaths{client: client}
	if _, err := paths.filters(t.Context()); err != nil {
		t.Fatal(err)
	}
	if got := newSplitTunnelTestClient(t, dir).handler.Filters().ProcessPathRegex; !reflect.DeepEqual(got, []string{userPattern}) {
		t.Fatalf("orphan cleanup changed user rules or left a bypass: %v", got)
	}
}
