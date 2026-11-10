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
	"slices"
	"sync"
	"testing"

	"github.com/getlantern/lantern/lantern-core/internal/processpath"
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
	return c.handler.State().Filters, nil
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

func (c *splitTunnelTestClient) SplitTunnelState(context.Context) (vpn.SplitTunnelState, error) {
	return c.handler.State(), nil
}

func (c *splitTunnelTestClient) SwitchSplitTunnelPolicy(_ context.Context, policy vpn.SplitTunnelPolicy) (vpn.SplitTunnelState, error) {
	err := c.handler.SwitchPolicy(policy)
	return c.handler.State(), err
}

func (c *splitTunnelTestClient) ClearSplitTunnelApps(context.Context) (vpn.SplitTunnelState, error) {
	err := c.handler.ClearApps()
	return c.handler.State(), err
}

func (c *splitTunnelTestClient) setEnabled(on bool) error {
	return c.handler.Configure(&on, nil)
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
			if !reflect.DeepEqual(client.handler.State().Filters, initial) {
				t.Fatal("failed save changed memory")
			}
			unblock()
			if !reflect.DeepEqual(newSplitTunnelTestClient(t, dir).handler.State().Filters, initial) {
				t.Fatal("failed save changed disk")
			}
			if err := paths.update(t.Context(), change, remove); err != nil {
				t.Fatal(err)
			}
			want := vpn.SplitTunnelFilter{Domain: initial.Domain}
			if !remove {
				want.ProcessPath = change.ProcessPath
			}
			if !reflect.DeepEqual(newSplitTunnelTestClient(t, dir).handler.State().Filters, want) {
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
			if err := client.setEnabled(enabled); err != nil {
				t.Fatal(err)
			}
			paths := splitTunnelPaths{client: client}
			unblock := blockSplitTunnelSave(t, dir)
			if err := paths.prepareConnect(t.Context()); (err != nil) != enabled {
				t.Fatalf("enabled=%v error=%v", enabled, err)
			}
			unblock()
			if err := client.setEnabled(true); err != nil {
				t.Fatal(err)
			}
			if err := paths.prepareConnect(t.Context()); err != nil {
				t.Fatal(err)
			}
			if len(client.handler.State().Filters.ProcessPathRegex) != 0 {
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
	if len(client.handler.State().Filters.ProcessPath) != 0 {
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
	if got := client.handler.State().Filters.ProcessPath; !reflect.DeepEqual(got, []string{"game.exe"}) {
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
	if got := newSplitTunnelTestClient(t, dir).handler.State().Filters.ProcessPathRegex; !reflect.DeepEqual(got, []string{userPattern}) {
		t.Fatalf("orphan cleanup changed user rules or left a bypass: %v", got)
	}
}

// legacySaveClient models an older daemon, which changes memory before a save that can fail.
type legacySaveClient struct {
	splitTunnelClient
	memory, saved []string
	failSave      bool
}

func (c *legacySaveClient) SplitTunnelFilters(context.Context) (vpn.SplitTunnelFilter, error) {
	return vpn.SplitTunnelFilter{ProcessPath: slices.Clone(c.memory)}, nil
}

func (c *legacySaveClient) AddSplitTunnelItems(_ context.Context, filter vpn.SplitTunnelFilter) error {
	c.memory = append(c.memory, filter.ProcessPath...)
	return c.save()
}

func (c *legacySaveClient) RemoveSplitTunnelItems(_ context.Context, filter vpn.SplitTunnelFilter) error {
	c.memory = slices.DeleteFunc(c.memory, func(path string) bool { return slices.Contains(filter.ProcessPath, path) })
	return c.save()
}

func (c *legacySaveClient) save() error {
	if c.failSave {
		return errors.New("save failed")
	}
	c.saved = slices.Clone(c.memory)
	return nil
}

func TestSplitTunnelPathsRetriesLegacyFailedSave(t *testing.T) {
	client := &legacySaveClient{failSave: true}
	paths := splitTunnelPaths{client: client}
	change := vpn.SplitTunnelFilter{ProcessPath: []string{processpath.Normalize("game.exe")}}
	if err := paths.update(t.Context(), change, false); err == nil {
		t.Fatal("save unexpectedly succeeded")
	}
	client.failSave = false
	if _, err := paths.filters(t.Context()); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(client.saved, client.memory) {
		t.Fatalf("saved %v, memory %v", client.saved, client.memory)
	}
}
