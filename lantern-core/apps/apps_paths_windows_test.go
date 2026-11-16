//go:build windows

package apps

import (
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/sys/windows"
)

func TestNormalizeAppPaths(t *testing.T) {
	path := filepath.Join(t.TempDir(), "Game Client", "Game.exe")
	writeFile(t, path, "fixture", 0o600)
	path = longAppPath(t, path)
	short := shortAppPath(t, path)
	app := &AppData{AppPath: short, BundleID: short, Name: "Game"}
	packaged := &AppData{AppPath: short, BundleID: "publisher.game"}
	normalizeAppPaths(nil, app, packaged)
	want := strings.ToLower(path)
	if app.AppPath != want || app.BundleID != want {
		t.Fatalf("normalized executable identity = (%q, %q), want %q", app.AppPath, app.BundleID, want)
	}
	if packaged.AppPath != want || packaged.BundleID != "publisher.game" {
		t.Fatalf("packaged app identity changed: %+v", packaged)
	}
	if app.Name != "Game" {
		t.Fatalf("display name changed: %q", app.Name)
	}
}

func TestLoadCacheExpandsShortAppPaths(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "Game Client", "Game.exe")
	writeFile(t, path, "fixture", 0o600)
	path = longAppPath(t, path)
	short := shortAppPath(t, path)
	if err := saveCacheToFile(dir, &AppData{AppPath: short, BundleID: short}); err != nil {
		t.Fatal(err)
	}
	apps, err := loadCacheFromFile(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(apps) != 1 || apps[0].AppPath != strings.ToLower(path) {
		t.Fatalf("cached paths were not normalized: %+v", apps)
	}
}

func shortAppPath(t *testing.T, path string) string {
	t.Helper()
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		t.Fatal(err)
	}
	buf := make([]uint16, 32768)
	n, err := windows.GetShortPathName(p, &buf[0], uint32(len(buf)))
	if err != nil || n == 0 || n >= uint32(len(buf)) {
		t.Fatalf("GetShortPathName failed: length=%d, error=%v", n, err)
	}
	short := windows.UTF16ToString(buf[:n])
	if strings.EqualFold(short, path) {
		t.Skip("filesystem does not provide 8.3 aliases")
	}
	return short
}

func longAppPath(t *testing.T, path string) string {
	t.Helper()
	p, err := windows.UTF16PtrFromString(`\\?\` + path)
	if err != nil {
		t.Fatal(err)
	}
	buf := make([]uint16, windows.MAX_LONG_PATH)
	n, err := windows.GetLongPathName(p, &buf[0], uint32(len(buf)))
	if err != nil || n == 0 || n >= uint32(len(buf)) {
		t.Fatalf("GetLongPathName failed: length=%d, error=%v", n, err)
	}
	return strings.TrimPrefix(windows.UTF16ToString(buf[:n]), `\\?\`)
}
