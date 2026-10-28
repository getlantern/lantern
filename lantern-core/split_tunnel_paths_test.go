//go:build !novpn

package lanterncore

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"reflect"
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
		t.Run(fmt.Sprint(remove), func(t *testing.T) {
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
			change := vpn.SplitTunnelFilter{ProcessPath: []string{"game.exe"}}
			unblock := blockSplitTunnelSave(t, dir)
			if err := paths.update(t.Context(), change, remove); err == nil {
				t.Fatal("save unexpectedly succeeded")
			}
			if !reflect.DeepEqual(client.handler.Filters(), initial) {
				t.Fatal("failed save changed memory")
			}
			unblock()
			if !reflect.DeepEqual(newSplitTunnelTestClient(t, dir).handler.Filters(), initial) {
				t.Fatal("failed save changed disk")
			}
			if err := paths.update(t.Context(), change, remove); err != nil {
				t.Fatal(err)
			}
			want := vpn.SplitTunnelFilter{Domain: initial.Domain}
			if !remove {
				want.ProcessPath = change.ProcessPath
			}
			if !reflect.DeepEqual(newSplitTunnelTestClient(t, dir).handler.Filters(), want) {
				t.Fatal("retry did not persist update")
			}
		})
	}
}

func TestSplitTunnelPathsPreparesEnabledConnections(t *testing.T) {
	for _, enabled := range []bool{false, true} {
		t.Run(fmt.Sprint(enabled), func(t *testing.T) {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			if err := client.handler.AddItems(vpn.SplitTunnelFilter{ProcessPathRegex: []string{`(?i)^(?P<lantern_windows_executable>)C:\\Old\\Game\.exe$`}}); err != nil {
				t.Fatal(err)
			}
			if err := client.handler.SetEnabled(enabled); err != nil {
				t.Fatal(err)
			}
			paths := splitTunnelPaths{client: client}
			unblock := blockSplitTunnelSave(t, dir)
			if err := paths.prepareConnect(t.Context()); (err != nil) != enabled {
				t.Fatalf("enabled=%v error=%v", enabled, err)
			}
			unblock()
			if err := client.handler.SetEnabled(true); err != nil {
				t.Fatal(err)
			}
			if err := paths.prepareConnect(t.Context()); err != nil {
				t.Fatal(err)
			}
			if len(client.handler.Filters().ProcessPathRegex) != 0 {
				t.Fatal("orphan alias was retained")
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
	if len(client.handler.Filters().ProcessPath) != 0 {
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
