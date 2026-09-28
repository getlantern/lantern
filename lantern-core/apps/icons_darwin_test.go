//go:build darwin && !ios

package apps

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGetIconPath_LiteralBundlePaths(t *testing.T) {
	for _, name := range []string{"App [Beta]", "App ["} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			native := makeAppBundle(t, root, name, "test.native", true)
			wrapped := makeWrappedAppBundle(t, root, name+" Wrapped", "Inner [Beta]", "test.wrapped")
			for app, want := range map[string]string{
				native:  filepath.Join(native, "Contents", "Resources", "AppIcon.icns"),
				wrapped: filepath.Join(wrapped, "Wrapper", "Inner [Beta].app", "AppIcon60x60@3x.png"),
			} {
				got, err := getIconPath(app)
				if err != nil {
					t.Fatal(err)
				}
				if got != want {
					t.Errorf("getIconPath(%q) = %q, want %q", app, got, want)
				}
			}
		})
	}
}

func TestWrappedIconPath_RanksByPixelsNotBytes(t *testing.T) {
	root := t.TempDir()
	app := makeWrappedAppBundle(t, root, "Ranked", "Inner", "test.ranked")
	inner := filepath.Join(app, "Wrapper", "Inner.app")
	for _, e := range []struct{ name, data string }{
		{"AppIcon40x40.png", pngBytes(t, 40, true)},   // few pixels, many bytes
		{"AppIcon1024.png", pngBytes(t, 1024, false)}, // many pixels, few bytes
		{"AppIcon-bad.png", "not a png"},
	} {
		writeFile(t, filepath.Join(inner, e.name), e.data, 0o644)
	}
	if err := os.Remove(filepath.Join(inner, "AppIcon60x60@3x.png")); err != nil {
		t.Fatal(err)
	}
	small, _ := os.Stat(filepath.Join(inner, "AppIcon40x40.png"))
	large, _ := os.Stat(filepath.Join(inner, "AppIcon1024.png"))
	if small.Size() <= large.Size() {
		t.Fatalf("fixture invalid: noisy 40px icon (%d B) should exceed flat 1024px icon (%d B)", small.Size(), large.Size())
	}
	want := filepath.Join(inner, "AppIcon1024.png")
	if got := wrappedIconPath(app); got != want {
		t.Errorf("wrappedIconPath = %q, want %q", got, want)
	}
}
