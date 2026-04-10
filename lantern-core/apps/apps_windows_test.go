//go:build windows

package apps

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsWindowsSystemApp(t *testing.T) {
	winDir := normalizedWindowsDir()
	system32Path := filepath.Join(winDir, "System32", "svchost.exe")
	syswow64Path := filepath.Join(winDir, "SysWOW64", "taskhostw.exe")
	winSxSPath := filepath.Join(winDir, "WinSxS", "amd64_component", "RuntimeBroker.exe")

	tests := []struct {
		name    string
		exePath string
		appName string
		want    bool
	}{
		{
			name:    "system32 path",
			exePath: system32Path,
			appName: "svchost",
			want:    true,
		},
		{
			name:    "syswow64 path",
			exePath: syswow64Path,
			appName: "taskhostw",
			want:    true,
		},
		{
			name:    "winsxs path",
			exePath: winSxSPath,
			appName: "runtimebroker",
			want:    true,
		},
		{
			name:    "normal app path",
			exePath: `C:\Program Files\Example App\example.exe`,
			appName: "Example App",
			want:    false,
		},
		{
			name:    "fallback by host name when path missing",
			exePath: ``,
			appName: "svchost",
			want:    true,
		},
		{
			name:    "non-host name when path missing",
			exePath: ``,
			appName: "my app",
			want:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isWindowsSystemApp(tt.exePath, tt.appName)
			if got != tt.want {
				t.Fatalf("isWindowsSystemApp(%q, %q) = %v, want %v", tt.exePath, tt.appName, got, tt.want)
			}
		})
	}
}

func TestIsNonUserFacingUninstallEntry(t *testing.T) {
	tests := []struct {
		name     string
		metadata uninstallEntryMetadata
		want     bool
	}{
		{
			name: "system component",
			metadata: uninstallEntryMetadata{
				systemComponentSet: true,
				systemComponent:    1,
			},
			want: true,
		},
		{
			name: "system component explicitly zero",
			metadata: uninstallEntryMetadata{
				systemComponentSet: true,
				systemComponent:    0,
			},
			want: false,
		},
		{
			name:     "no flags",
			metadata: uninstallEntryMetadata{},
			want:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isNonUserFacingUninstallEntry(tt.metadata)
			if got != tt.want {
				t.Fatalf("isNonUserFacingUninstallEntry(%+v) = %v, want %v", tt.metadata, got, tt.want)
			}
		})
	}
}

func TestResolveWrappedExecutable(t *testing.T) {
	t.Run("returns original path when executable is not wrapper", func(t *testing.T) {
		dir := t.TempDir()
		normalExe := filepath.Join(dir, "Claude.exe")
		if err := os.WriteFile(normalExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write normal exe: %v", err)
		}

		got := resolveWrappedExecutable(normalExe, "Claude")
		if got != normalExe {
			t.Fatalf("resolveWrappedExecutable(%q, Claude) = %q, want %q", normalExe, got, normalExe)
		}
	})

	t.Run("resolves Update.exe wrapper to hinted app exe", func(t *testing.T) {
		dir := t.TempDir()
		updateExe := filepath.Join(dir, "Update.exe")
		claudeExe := filepath.Join(dir, "Claude.exe")
		if err := os.WriteFile(updateExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write update exe: %v", err)
		}
		if err := os.WriteFile(claudeExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write claude exe: %v", err)
		}

		got := resolveWrappedExecutable(updateExe, "Claude")
		if got != claudeExe {
			t.Fatalf("resolveWrappedExecutable(%q, Claude) = %q, want %q", updateExe, got, claudeExe)
		}
	})

	t.Run("returns only non-wrapper executable when unique", func(t *testing.T) {
		dir := t.TempDir()
		updateExe := filepath.Join(dir, "Update.exe")
		appExe := filepath.Join(dir, "App.exe")
		if err := os.WriteFile(updateExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write update exe: %v", err)
		}
		if err := os.WriteFile(appExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write app exe: %v", err)
		}

		got := resolveWrappedExecutable(updateExe, "")
		if got != appExe {
			t.Fatalf("resolveWrappedExecutable(%q, \"\") = %q, want %q", updateExe, got, appExe)
		}
	})

	t.Run("returns empty when wrapper has multiple non-wrapper candidates and no hint", func(t *testing.T) {
		dir := t.TempDir()
		updateExe := filepath.Join(dir, "Update.exe")
		appA := filepath.Join(dir, "A.exe")
		appB := filepath.Join(dir, "B.exe")
		for _, path := range []string{updateExe, appA, appB} {
			if err := os.WriteFile(path, []byte(""), 0o644); err != nil {
				t.Fatalf("write %s: %v", path, err)
			}
		}

		got := resolveWrappedExecutable(updateExe, "")
		if got != "" {
			t.Fatalf("resolveWrappedExecutable(%q, \"\") = %q, want empty", updateExe, got)
		}
	})

	t.Run("returns empty for relative wrapper path", func(t *testing.T) {
		got := resolveWrappedExecutable("Update.exe", "Claude")
		if got != "" {
			t.Fatalf("resolveWrappedExecutable(relative Update.exe, Claude) = %q, want empty", got)
		}
	})

	t.Run("matches hint when name uses uppercase EXE suffix", func(t *testing.T) {
		dir := t.TempDir()
		updateExe := filepath.Join(dir, "Update.exe")
		claudeExe := filepath.Join(dir, "Claude.exe")
		if err := os.WriteFile(updateExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write update exe: %v", err)
		}
		if err := os.WriteFile(claudeExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write claude exe: %v", err)
		}

		got := resolveWrappedExecutable(updateExe, "CLAUDE.EXE")
		if got != claudeExe {
			t.Fatalf("resolveWrappedExecutable(%q, CLAUDE.EXE) = %q, want %q", updateExe, got, claudeExe)
		}
	})

	t.Run("resolves wrapper when app executable is under app-version subdirectory", func(t *testing.T) {
		dir := t.TempDir()
		updateExe := filepath.Join(dir, "Update.exe")
		appVersionDir := filepath.Join(dir, "app-2.1.78")
		claudeExe := filepath.Join(appVersionDir, "Claude.exe")
		if err := os.WriteFile(updateExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write update exe: %v", err)
		}
		if err := os.MkdirAll(appVersionDir, 0o755); err != nil {
			t.Fatalf("mkdir app-version dir: %v", err)
		}
		if err := os.WriteFile(claudeExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write claude exe: %v", err)
		}

		got := resolveWrappedExecutable(updateExe, "Claude")
		if got != claudeExe {
			t.Fatalf("resolveWrappedExecutable(%q, Claude) = %q, want %q", updateExe, got, claudeExe)
		}
	})
}

func TestShortcutDisplayName(t *testing.T) {
	tests := []struct {
		name         string
		shortcutName string
		targetExe    string
		want         string
	}{
		{
			name:         "trims lower-case extension",
			shortcutName: "Claude.lnk",
			targetExe:    `C:\Program Files\Claude\Claude.exe`,
			want:         "Claude",
		},
		{
			name:         "trims upper-case extension",
			shortcutName: "Claude.LNK",
			targetExe:    `C:\Program Files\Claude\Claude.exe`,
			want:         "Claude",
		},
		{
			name:         "falls back to executable base name",
			shortcutName: "   ",
			targetExe:    `C:\Program Files\Claude\Claude.exe`,
			want:         "Claude",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := shortcutDisplayName(tt.shortcutName, tt.targetExe)
			if got != tt.want {
				t.Fatalf("shortcutDisplayName(%q, %q) = %q, want %q", tt.shortcutName, tt.targetExe, got, tt.want)
			}
		})
	}
}

func TestComputeWindowsSystemRoots(t *testing.T) {
	roots := computeWindowsSystemRoots()
	if len(roots) != 3 {
		t.Fatalf("computeWindowsSystemRoots() returned %d roots, want 3", len(roots))
	}

	for _, root := range roots {
		if strings.TrimSpace(root) == "" {
			t.Fatalf("computeWindowsSystemRoots() returned an empty root")
		}
	}
}

func TestPickExePathFallsBackWhenDisplayIconIsNonExe(t *testing.T) {
	dir := t.TempDir()

	exePath := filepath.Join(dir, "MyApp.exe")
	if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
		t.Fatalf("write exe: %v", err)
	}

	dllPath := filepath.Join(dir, "MyApp.dll")
	if err := os.WriteFile(dllPath, []byte(""), 0o644); err != nil {
		t.Fatalf("write dll: %v", err)
	}

	got := pickExePath(dllPath, dir)
	if got != exePath {
		t.Fatalf("pickExePath(%q, %q) = %q, want %q", dllPath, dir, got, exePath)
	}
}
