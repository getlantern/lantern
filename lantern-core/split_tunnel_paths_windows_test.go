//go:build windows && !novpn

package lanterncore

import (
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/getlantern/lantern/lantern-core/internal/processpath"
	"github.com/getlantern/radiance/vpn"
	"golang.org/x/sys/windows"
)

func TestSplitTunnelWindowsMigratesSavedPaths(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	wantPath := strings.ToLower(path)
	alias := processpath.AliasPattern(wantPath)
	if alias == "" {
		t.Fatal("fixture has no alias rule")
	}
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
				want.ProcessPathRegex = append([]string{initial.ProcessPathRegex[0]}, alias)
				if !reflect.DeepEqual(got, want) {
					t.Fatalf("migrated filters = %#v, want %#v", got, want)
				}
				wantCalls := []string{"read", "add", "remove", "read"}
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
	if len(saved.ProcessPath) != 0 || len(saved.ProcessPathRegex) != 0 || !reflect.DeepEqual(saved.Domain, filter.Domain) {
		t.Fatalf("removing an alias changed other filters or left its path: %#v", saved)
	}
}

func TestSplitTunnelWindowsRemovesMissingExecutable(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	other, _ := splitTunnelAliasFixture(t)
	dir := t.TempDir()
	client := newSplitTunnelTestClient(t, dir)
	paths := splitTunnelPaths{client: client}
	userPattern := `(?i)^C:\\Games\\Other\.exe$`
	if err := paths.update(t.Context(), vpn.SplitTunnelFilter{
		ProcessPath:      []string{short, other},
		ProcessPathRegex: []string{userPattern},
	}, false); err != nil {
		t.Fatal(err)
	}
	if len(client.handler.Filters().ProcessPathRegex) != 3 {
		t.Fatal("expected a generated rule for each executable")
	}
	if err := os.Remove(path); err != nil {
		t.Fatal(err)
	}
	// Reload both sides so cleanup cannot depend on in-memory alias bookkeeping.
	client = newSplitTunnelTestClient(t, dir)
	paths = splitTunnelPaths{client: client}
	if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{path}}, true); err != nil {
		t.Fatal(err)
	}
	saved := newSplitTunnelTestClient(t, dir).handler.Filters()
	if !reflect.DeepEqual(saved.ProcessPath, []string{strings.ToLower(other)}) ||
		!reflect.DeepEqual(saved.ProcessPathRegex, []string{userPattern, processpath.AliasPattern(other)}) {
		t.Fatalf("removing missing executable left aliases or changed other rules: %#v", saved)
	}
}

func TestSplitTunnelWindowsRemovesCanonicalLegacyPath(t *testing.T) {
	path, _ := splitTunnelAliasFixture(t)
	canonical := strings.ToLower(path)
	dir := t.TempDir()
	client := newSplitTunnelTestClient(t, dir)
	if err := client.handler.AddItems(vpn.SplitTunnelFilter{ProcessPath: []string{canonical}}); err != nil {
		t.Fatal(err)
	}
	paths := splitTunnelPaths{client: client}
	if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{canonical}}, true); err != nil {
		t.Fatal(err)
	}
	for _, saved := range []vpn.SplitTunnelFilter{client.handler.Filters(), newSplitTunnelTestClient(t, dir).handler.Filters()} {
		if len(saved.ProcessPath) != 0 || len(saved.ProcessPathRegex) != 0 {
			t.Fatalf("removing a canonical legacy path left selectors: %#v", saved)
		}
	}
}

func TestSplitTunnelWindowsRefreshesStaleAliases(t *testing.T) {
	path, _ := splitTunnelAliasFixture(t)
	canonical := strings.ToLower(path)
	alias := processpath.AliasPattern(canonical)
	if alias == "" {
		t.Fatal("fixture has no alias rule")
	}
	stale := strings.TrimSuffix(alias, "$") + "obsolete$"
	userPattern := `Other.*\.exe$`
	dir := t.TempDir()
	client := newSplitTunnelTestClient(t, dir)
	if err := client.handler.AddItems(vpn.SplitTunnelFilter{
		ProcessPath:      []string{canonical},
		ProcessPathRegex: []string{stale, userPattern},
	}); err != nil {
		t.Fatal(err)
	}
	if err := client.handler.SetEnabled(true); err != nil {
		t.Fatal(err)
	}
	paths := splitTunnelPaths{client: client}
	if err := paths.prepareConnect(t.Context()); err != nil {
		t.Fatal(err)
	}
	got := newSplitTunnelTestClient(t, dir).handler.Filters().ProcessPathRegex
	if !reflect.DeepEqual(got, []string{userPattern, alias}) {
		t.Fatalf("saved patterns = %v", got)
	}
}

func TestSplitTunnelWindowsRetriesAliasUpdate(t *testing.T) {
	path, short := splitTunnelAliasFixture(t)
	for _, remove := range []bool{false, true} {
		name := "add"
		if remove {
			name = "remove"
		}
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			client := newSplitTunnelTestClient(t, dir)
			paths := splitTunnelPaths{client: client}
			if err := client.handler.AddItems(vpn.SplitTunnelFilter{Domain: []string{"example.com"}}); err != nil {
				t.Fatal(err)
			}
			if remove {
				if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{path}}, false); err != nil {
					t.Fatal(err)
				}
			}
			initial := client.handler.Filters()
			unblock := blockSplitTunnelSave(t, dir)
			if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{short}}, remove); err == nil {
				t.Fatal("update succeeded while saving was blocked")
			}
			want := vpn.SplitTunnelFilter{Domain: initial.Domain}
			if !remove {
				want.ProcessPath = []string{strings.ToLower(path)}
				want.ProcessPathRegex = []string{processpath.AliasPattern(path)}
			}
			got := client.handler.Filters()
			if !slices.Equal(got.ProcessPath, initial.ProcessPath) || !slices.Equal(got.ProcessPathRegex, initial.ProcessPathRegex) {
				t.Fatalf("failed save changed path or alias: %#v", got)
			}
			unblock()
			if got := newSplitTunnelTestClient(t, dir).handler.Filters(); !reflect.DeepEqual(got, initial) {
				t.Fatalf("failed save changed disk: %#v", got)
			}
			if err := paths.update(t.Context(), vpn.SplitTunnelFilter{ProcessPath: []string{short}}, remove); err != nil {
				t.Fatal(err)
			}
			if got := newSplitTunnelTestClient(t, dir).handler.Filters(); !reflect.DeepEqual(got, want) {
				t.Fatalf("retried save = %#v, want %#v", got, want)
			}
		})
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
			wantCalls := []string{"read", "add"}
			wantMemory := []string{short}
			if operation == "remove" {
				wantCalls = append(wantCalls, "remove")
				wantMemory = []string{short, strings.ToLower(path)}
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
			wantRetry := []string{"read", "remove", "read"}
			if operation == "add" {
				wantRetry = []string{"read", "add", "remove", "read"}
			}
			if !reflect.DeepEqual(client.calls, wantRetry) {
				t.Fatalf("retry calls=%v", client.calls)
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
