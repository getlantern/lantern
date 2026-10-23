package processpath

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/sys/windows"
)

func TestNormalizeWindowsPaths(t *testing.T) {
	for _, path := range []string{
		"",
		`Game.EXE`,
		`.\Games\..\GAME.EXE`,
		`C:Game.EXE`,
		`\Games\GAME.EXE`,
		`\\server.invalid\share\GAME.EXE`,
		`\\server.invalid\share\Games\..\GAME.EXE`,
		`\\?\C:\Games\GAME.EXE`,
		`\\?\C:\Games\..\GAME.EXE`,
		`\\.\C:\Games\GAME.EXE`,
	} {
		if got, want := Normalize(path), strings.ToLower(path); got != want {
			t.Errorf("Normalize(%q) = %q, want %q", path, got, want)
		}
	}

	path := filepath.Join(t.TempDir(), "Missing Game.exe")
	variant := strings.ReplaceAll(strings.ToUpper(filepath.Dir(path))+`\unused\..\Missing Game.exe`, `\`, "/")
	if got, want := Normalize(variant), strings.ToLower(path); got != want {
		t.Errorf("Normalize(%q) = %q, want %q", variant, got, want)
	}
}

func TestNormalizeWindowsShortPath(t *testing.T) {
	for _, test := range []struct {
		name      string
		minLength int
	}{
		{"short path", 0},
		{"long path", windows.MAX_PATH + 80},
	} {
		t.Run(test.name, func(t *testing.T) {
			dir := windowsLongPath(t, t.TempDir())
			for len(dir) < test.minLength {
				dir = filepath.Join(dir, "Long Game Directory")
			}
			if err := os.MkdirAll(dir, 0o700); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(dir, "Launcher Child Executable.exe")
			if err := os.WriteFile(path, nil, 0o600); err != nil {
				t.Fatal(err)
			}
			input, err := windows.UTF16PtrFromString(`\\?\` + path)
			if err != nil {
				t.Fatal(err)
			}
			buffer := make([]uint16, windows.MAX_LONG_PATH)
			n, err := windows.GetShortPathName(input, &buffer[0], uint32(len(buffer)))
			if err != nil {
				t.Fatal(err)
			}
			if n == 0 || int(n) >= len(buffer) {
				t.Fatalf("GetShortPathName(%q) returned invalid length %d", path, n)
			}
			short := strings.TrimPrefix(windows.UTF16ToString(buffer[:n]), `\\?\`)
			if strings.EqualFold(short, path) {
				if os.Getenv("LANTERN_REQUIRE_SHORT_PATH_TEST") == "1" {
					t.Fatal("8.3 aliases are disabled on the test volume")
				}
				t.Skip("8.3 aliases are disabled on this volume")
			}
			if got, want := Normalize(short), strings.ToLower(path); got != want {
				t.Errorf("Normalize(%q) = %q, want %q", short, got, want)
			}
		})
	}
}

func windowsLongPath(t *testing.T, path string) string {
	t.Helper()
	input, err := windows.UTF16PtrFromString(`\\?\` + path)
	if err != nil {
		t.Fatal(err)
	}
	buffer := make([]uint16, windows.MAX_LONG_PATH)
	n, err := windows.GetLongPathName(input, &buffer[0], uint32(len(buffer)))
	if err != nil {
		t.Fatal(err)
	}
	if n == 0 || int(n) >= len(buffer) {
		t.Fatalf("GetLongPathName(%q) returned invalid length %d", path, n)
	}
	return strings.TrimPrefix(windows.UTF16ToString(buffer[:n]), `\\?\`)
}

func TestNormalizeWindowsReparsePoints(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "Game Directory")
	if err := os.Mkdir(target, 0o700); err != nil {
		t.Fatal(err)
	}
	game := filepath.Join(target, "Game Executable.exe")
	if err := os.WriteFile(game, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	for _, kind := range []string{"file symlink", "directory symlink", "junction"} {
		t.Run(kind, func(t *testing.T) {
			link := filepath.Join(dir, kind)
			path := filepath.Join(link, filepath.Base(game))
			var err error
			switch kind {
			case "file symlink":
				err = os.Symlink(game, link)
				path = link
			case "directory symlink":
				err = os.Symlink(target, link)
			case "junction":
				ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
				defer cancel()
				output, err := exec.CommandContext(ctx, "cmd", "/c", "mklink", "/J", link, target).CombinedOutput()
				if err != nil {
					t.Fatalf("create junction: %v: %s", err, output)
				}
			}
			if errors.Is(err, windows.ERROR_PRIVILEGE_NOT_HELD) {
				t.Skip("symlink privilege unavailable")
			}
			if err != nil {
				t.Fatal(err)
			}
			if got, want := Normalize(path), strings.ToLower(path); got != want {
				t.Errorf("Normalize(%q) = %q, want %q", path, got, want)
			}
		})
	}
}
