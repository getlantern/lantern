//go:build !windows

package processpath

import "testing"

func TestNormalizePreservesOtherPlatforms(t *testing.T) {
	for _, path := range []string{"", "/Applications/My App.app", "/usr/bin/../lib/game", `C:\Games\GAME.EXE`} {
		if got := Normalize(path); got != path {
			t.Errorf("Normalize(%q) = %q", path, got)
		}
	}
}
