//go:build darwin && !ios

package apps

import (
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
