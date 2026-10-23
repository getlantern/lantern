//go:build windows && !novpn

package lanterncore

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/getlantern/radiance/vpn"
	"golang.org/x/sys/windows"
)

func TestSplitTunnelWindowsMigratesSavedPaths(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	wantPath := strings.ToLower(path)
	for _, policy := range []vpn.SplitTunnelPolicy{vpn.SplitTunnelPolicyExclude, vpn.SplitTunnelPolicyInclude} {
		for _, tc := range []struct {
			name  string
			paths []string
		}{
			{"short path", []string{short}},
			{"case and separators", []string{filepath.ToSlash(strings.ToUpper(path))}},
			{"existing replacement", []string{short, strings.ToUpper(path), wantPath}},
		} {
			t.Run(string(policy)+"/"+tc.name, func(t *testing.T) {
				dir := t.TempDir()
				client := newSplitTunnelTestClient(t, dir)
				initial := vpn.SplitTunnelFilter{
					Domain:           []string{"example.com"},
					DomainSuffix:     []string{"example.org"},
					DomainKeyword:    []string{"example"},
					DomainRegex:      []string{`^example\.net$`},
					ProcessName:      []string{"other.exe"},
					ProcessPath:      tc.paths,
					ProcessPathRegex: []string{`Other.*\.exe$`},
					PackageName:      []string{"org.example.app"},
				}
				if err := client.handler.AddItems(initial); err != nil {
					t.Fatal(err)
				}
				if err := client.handler.SetEnabled(true); err != nil {
					t.Fatal(err)
				}
				if err := client.handler.SetPolicy(policy); err != nil {
					t.Fatal(err)
				}
				paths := splitTunnelPaths{client: client}
				got, err := paths.filters(t.Context())
				if err != nil {
					t.Fatal(err)
				}
				want := initial
				want.ProcessPath = []string{wantPath}
				if !reflect.DeepEqual(got, want) {
					t.Fatalf("migrated filters = %#v, want %#v", got, want)
				}
				wantCalls := []string{"read", "add", "remove", "read"}
				if tc.name == "existing replacement" {
					wantCalls = []string{"read", "remove", "read"}
				}
				if !reflect.DeepEqual(client.calls, wantCalls) {
					t.Fatalf("migration calls = %v, want %v", client.calls, wantCalls)
				}
				saved := newSplitTunnelTestClient(t, dir).handler
				if !reflect.DeepEqual(saved.Filters(), want) || !saved.IsEnabled() || saved.Policy() != policy {
					t.Fatal("migration did not preserve the saved filters, enabled state, and policy")
				}
				client.calls = nil
				if _, err := paths.filters(t.Context()); err != nil {
					t.Fatal(err)
				}
				if !reflect.DeepEqual(client.calls, []string{"read"}) {
					t.Fatalf("repeated migration wrote filters: %v", client.calls)
				}
			})
		}
	}
}

func TestSplitTunnelWindowsNormalizesUpdates(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	dir := t.TempDir()
	client := newSplitTunnelTestClient(t, dir)
	paths := splitTunnelPaths{client: client}
	filter := vpn.SplitTunnelFilter{
		ProcessPath: []string{short, filepath.ToSlash(strings.ToUpper(path)), path},
		Domain:      []string{"example.com"},
	}
	if err := paths.update(t.Context(), filter, false); err != nil {
		t.Fatal(err)
	}
	if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{path}}, false); err != nil {
		t.Fatal(err)
	}
	if got := client.handler.Filters().ProcessPath; !reflect.DeepEqual(got, []string{strings.ToLower(path)}) {
		t.Fatalf("saved paths = %v", got)
	}
	if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{short}}, true); err != nil {
		t.Fatal(err)
	}
	saved := newSplitTunnelTestClient(t, dir).handler.Filters()
	if len(saved.ProcessPath) != 0 || !reflect.DeepEqual(saved.Domain, filter.Domain) {
		t.Fatalf("removing an alias changed other filters or left its path: %#v", saved)
	}
}

func TestSplitTunnelWindowsRetriesFailedMigration(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	for _, operation := range []string{"add", "remove"} {
		t.Run(operation, func(t *testing.T) {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			if err := client.handler.AddItems(vpn.SplitTunnelFilter{ProcessPath: []string{short}}); err != nil {
				t.Fatal(err)
			}
			var unblock func()
			if operation == "add" {
				unblock = blockSplitTunnelSave(t, dir)
			} else {
				client.beforeRemove = func() {
					unblock = blockSplitTunnelSave(t, dir)
					client.beforeRemove = nil
				}
			}
			paths := splitTunnelPaths{client: client}
			if _, err := paths.filters(t.Context()); err == nil {
				t.Fatal("migration succeeded while saving was blocked")
			}
			if !paths.pendingSave {
				t.Fatal("failed migration was not retained for retry")
			}
			wantCalls := []string{"read", "add"}
			wantMemory := []string{short, strings.ToLower(path)}
			if operation == "remove" {
				wantCalls = append(wantCalls, "remove")
				wantMemory = []string{strings.ToLower(path)}
			}
			if !reflect.DeepEqual(client.calls, wantCalls) {
				t.Fatalf("failed migration calls = %v, want %v", client.calls, wantCalls)
			}
			if got := client.handler.Filters().ProcessPath; !reflect.DeepEqual(got, wantMemory) {
				t.Fatalf("in-memory paths = %v, want %v", got, wantMemory)
			}
			if unblock == nil {
				t.Fatal("migration did not reach the failing write")
			}
			unblock()
			client.calls = nil
			if _, err := paths.filters(t.Context()); err != nil {
				t.Fatal(err)
			}
			if paths.pendingSave || !reflect.DeepEqual(client.calls, []string{"read", "remove", "read"}) {
				t.Fatalf("retry pending=%v, calls=%v", paths.pendingSave, client.calls)
			}
			if got := newSplitTunnelTestClient(t, dir).handler.Filters().ProcessPath; !reflect.DeepEqual(got, []string{strings.ToLower(path)}) {
				t.Fatalf("saved paths after retry = %v", got)
			}
		})
	}
}

func splitTunnelAliasFixture(t *testing.T) (string, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "Launcher Child Executable.exe")
	if err := os.WriteFile(path, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	input, err := windows.UTF16PtrFromString(path)
	if err != nil {
		t.Fatal(err)
	}
	buffer := make([]uint16, windows.MAX_LONG_PATH)
	n, err := windows.GetLongPathName(input, &buffer[0], uint32(len(buffer)))
	if err != nil || n == 0 || n >= uint32(len(buffer)) {
		t.Fatalf("GetLongPathName: length=%d, error=%v", n, err)
	}
	path = windows.UTF16ToString(buffer[:n])
	n, err = windows.GetShortPathName(input, &buffer[0], uint32(len(buffer)))
	if err != nil || n == 0 || n >= uint32(len(buffer)) {
		t.Fatalf("GetShortPathName: length=%d, error=%v", n, err)
	}
	short := windows.UTF16ToString(buffer[:n])
	if strings.EqualFold(short, path) {
		if os.Getenv("LANTERN_REQUIRE_SHORT_PATH_TEST") == "1" {
			t.Fatal("8.3 aliases are disabled on the test volume")
		}
		t.Skip("8.3 aliases are disabled on this volume")
	}
	return path, short
}
