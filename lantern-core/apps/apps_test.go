package apps

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, path, content string, mode os.FileMode) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), mode); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func makeAppBundle(t *testing.T, root, name, bundleID string, withIcon bool) string {
	t.Helper()
	app := filepath.Join(root, name+".app")
	infoPlist := `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>` + bundleID + `</string>
</dict>
</plist>`
	writeFile(t, filepath.Join(app, "Contents", "Info.plist"), infoPlist, 0o644)
	if withIcon {
		writeFile(t, filepath.Join(app, "Contents", "Resources", "AppIcon.icns"), "notreal", 0o644)
	}
	return app
}

func TestScanAppDirs_FindsAppsAndIcon(t *testing.T) {
	tmp := t.TempDir()
	root := filepath.Join(tmp, "Applications")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	appPath := makeAppBundle(t, root, "Lantern", "org.getlantern.lantern", true)

	var got []*AppData
	cb := func(a ...*AppData) error {
		got = append(got, a...)
		return nil
	}

	apps := scanAppDirs([]string{root}, map[string]bool{}, excludeDirs, cb)
	if len(apps) != 1 {
		t.Fatalf("expected 1 app, got %d", len(apps))
	}
	if apps[0].BundleID != "org.getlantern.lantern" {
		t.Fatalf("bundle ID mismatch: %s", apps[0].BundleID)
	}
	if apps[0].AppPath != appPath {
		t.Fatalf("app path mismatch: %s", apps[0].AppPath)
	}
	if apps[0].Name != "Lantern" {
		t.Fatalf("app name mismatch: %s", apps[0].Name)
	}
	if !strings.HasSuffix(apps[0].IconPath, ".icns") {
		t.Fatalf("expected an .icns icon, got %q", apps[0].IconPath)
	}
	// Callback received the same item
	if len(got) != 1 || got[0].BundleID != "org.getlantern.lantern" {
		t.Fatalf("callback did not receive app data")
	}
}

func TestScanAppDirs_DedupByBundleID(t *testing.T) {
	tmp := t.TempDir()
	root := filepath.Join(tmp, "Applications")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	makeAppBundle(t, root, "A", "com.example.same", false)
	// Same bundle ID, different name/path
	makeAppBundle(t, root, "B", "com.example.same", false)

	var got []*AppData
	cb := func(a ...*AppData) error { got = append(got, a...); return nil }

	apps := scanAppDirs([]string{root}, map[string]bool{}, excludeDirs, cb)
	if len(apps) != 1 {
		t.Fatalf("expected 1 app due to de-dup, got %d", len(apps))
	}
	if apps[0].BundleID != "com.example.same" {
		t.Fatalf("unexpected bundle id: %s", apps[0].BundleID)
	}
}

func TestCacheLoadSaveRoundTrip(t *testing.T) {
	tmp := t.TempDir()
	a1 := &AppData{Name: "One", BundleID: "com.x.one", AppPath: "/X/One.app"}
	a2 := &AppData{Name: "Two", BundleID: "com.x.two", AppPath: "/X/Two.app"}

	if err := saveCacheToFile(tmp, a1, a2); err != nil {
		t.Fatalf("save cache: %v", err)
	}
	got, err := loadCacheFromFile(tmp)
	if err != nil {
		t.Fatalf("load cache: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2, got %d", len(got))
	}
}

func TestLoadInstalledAppsWithDirs_EmitsCachedThenNew(t *testing.T) {
	tmp := t.TempDir()

	cached := &AppData{Name: "Cached", BundleID: "com.cached", AppPath: "/Cached.app"}
	if err := saveCacheToFile(tmp, cached); err != nil {
		t.Fatalf("seed cache: %v", err)
	}

	root := filepath.Join(tmp, "ScanRoot")
	if err := os.MkdirAll(root, 0o755); err != nil {
		t.Fatal(err)
	}
	makeAppBundle(t, root, "Fresh", "com.fresh", false)

	var seen []string
	cb := func(a ...*AppData) error {
		for _, x := range a {
			seen = append(seen, x.BundleID)
		}
		return nil
	}

	n, err := LoadInstalledAppsWithDirs(tmp, []string{root}, excludeDirs, cb)
	if err != nil {
		t.Fatalf("got error: %v", err)
	}
	if n != 1 {
		t.Fatalf("expected 1 new app, got %d", n)
	}
	hasCached, hasFresh := false, false
	for _, b := range seen {
		if b == "com.cached" {
			hasCached = true
		}
		if b == "com.fresh" {
			hasFresh = true
		}
	}
	if !hasCached || !hasFresh {
		t.Fatalf("callback did not receive both cached and fresh apps; got %v", seen)
	}
}
