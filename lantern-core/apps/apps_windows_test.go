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
			name:    "file explorer by host executable name",
			exePath: `C:\Windows\explorer.exe`,
			appName: "File Explorer",
			want:    true,
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
			name: "no display",
			metadata: uninstallEntryMetadata{
				noDisplaySet: true,
				noDisplay:    1,
			},
			want: true,
		},
		{
			name: "has parent key name",
			metadata: uninstallEntryMetadata{
				parentKeyName: "VendorSuite",
			},
			want: true,
		},
		{
			name: "release type update",
			metadata: uninstallEntryMetadata{
				releaseType: "Security Update",
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

func TestIsWindowsUtilityApp(t *testing.T) {
	tests := []struct {
		name    string
		exePath string
		appName string
		want    bool
	}{
		{
			name:    "cmake gui display name variant",
			exePath: `C:\Program Files\CMake\bin\cmake-gui.exe`,
			appName: "CMake (cmake-gui)",
			want:    true,
		},
		{
			name:    "git cmd display name variant",
			exePath: "",
			appName: "Git CMD",
			want:    true,
		},
		{
			name:    "office language preferences display name",
			exePath: "",
			appName: "Office Language Preferences",
			want:    true,
		},
		{
			name:    "pc health check display name",
			exePath: "",
			appName: "PC Health Check",
			want:    true,
		},
		{
			name:    "regular app not utility",
			exePath: `C:\Users\user\AppData\Local\AnthropicClaude\Claude.exe`,
			appName: "Claude",
			want:    false,
		},
		{
			name:    "awk utility binary",
			exePath: `C:\Program Files\Git\usr\bin\awk.exe`,
			appName: "Awk",
			want:    true,
		},
		{
			name:    "actions mcp host utility app",
			exePath: `C:\Users\user\AppData\Local\Microsoft\WindowsApps\ActionsMcpHost.exe`,
			appName: "ActionsMcpHost",
			want:    true,
		},
		{
			name:    "visual c++ redistributable utility",
			exePath: "",
			appName: "Microsoft Visual C++ 2015-2022 Redistributable (x64)",
			want:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isWindowsUtilityApp(tt.exePath, tt.appName)
			if got != tt.want {
				t.Fatalf("isWindowsUtilityApp(%q, %q) = %v, want %v", tt.exePath, tt.appName, got, tt.want)
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

	t.Run("resolves wrapper using processStart argument and working directory", func(t *testing.T) {
		root := t.TempDir()
		shortcutTarget := filepath.Join(root, "Update.exe")
		workingDir := filepath.Join(root, "dist")
		appDir := filepath.Join(workingDir, "app-2.1.78")
		claudeExe := filepath.Join(appDir, "Claude.exe")

		if err := os.WriteFile(shortcutTarget, []byte(""), 0o644); err != nil {
			t.Fatalf("write update exe: %v", err)
		}
		if err := os.MkdirAll(appDir, 0o755); err != nil {
			t.Fatalf("mkdir app dir: %v", err)
		}
		if err := os.WriteFile(claudeExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write claude exe: %v", err)
		}

		got := resolveWrappedExecutableWithContext(
			shortcutTarget,
			"Claude",
			`--processStart "Claude.exe" --process-start-args "--foo=bar"`,
			workingDir,
		)
		if got != claudeExe {
			t.Fatalf("resolveWrappedExecutableWithContext(...processStart...) = %q, want %q", got, claudeExe)
		}
	})
}

func TestResolveShortcutExecutable(t *testing.T) {
	t.Run("falls back to icon executable when shortcut target is system host", func(t *testing.T) {
		dir := t.TempDir()
		shortcutPath := filepath.Join(dir, "Claude.lnk")
		claudeExe := filepath.Join(dir, "Claude.exe")
		if err := os.WriteFile(claudeExe, []byte(""), 0o644); err != nil {
			t.Fatalf("write claude exe: %v", err)
		}

		systemHost := filepath.Join(normalizedWindowsDir(), "System32", "svchost.exe")
		got := resolveShortcutExecutable(
			systemHost,
			claudeExe,
			shortcutPath,
			"Claude",
			"",
			dir,
		)
		if got != claudeExe {
			t.Fatalf("resolveShortcutExecutable(system host, icon Claude.exe) = %q, want %q", got, claudeExe)
		}
	})
}

func TestNormalizeShortcutExecutablePath(t *testing.T) {
	t.Run("resolves relative target from working directory", func(t *testing.T) {
		root := t.TempDir()
		workingDir := filepath.Join(root, "dist")
		if err := os.MkdirAll(workingDir, 0o755); err != nil {
			t.Fatalf("mkdir working dir: %v", err)
		}
		exePath := filepath.Join(workingDir, "Claude.exe")
		if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
			t.Fatalf("write exe: %v", err)
		}

		got := normalizeShortcutExecutablePath("Claude.exe", workingDir, filepath.Join(root, "Claude.lnk"))
		if got != exePath {
			t.Fatalf("normalizeShortcutExecutablePath(relative, workingDir) = %q, want %q", got, exePath)
		}
	})

	t.Run("resolves relative target from shortcut directory when working directory is empty", func(t *testing.T) {
		root := t.TempDir()
		shortcutDir := filepath.Join(root, "Programs")
		if err := os.MkdirAll(shortcutDir, 0o755); err != nil {
			t.Fatalf("mkdir shortcut dir: %v", err)
		}
		exePath := filepath.Join(shortcutDir, "Claude.exe")
		if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
			t.Fatalf("write exe: %v", err)
		}
		shortcutPath := filepath.Join(shortcutDir, "Claude.lnk")

		got := normalizeShortcutExecutablePath("Claude.exe", "", shortcutPath)
		if got != exePath {
			t.Fatalf("normalizeShortcutExecutablePath(relative, shortcut dir) = %q, want %q", got, exePath)
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

func TestParseWindowsCommandTokens(t *testing.T) {
	tests := []struct {
		name    string
		command string
		want    []string
	}{
		{
			name:    "empty command",
			command: "",
			want:    nil,
		},
		{
			name:    "basic split",
			command: `--processStart Claude.exe --flag value`,
			want:    []string{"--processStart", "Claude.exe", "--flag", "value"},
		},
		{
			name:    "quoted token preserved",
			command: `--processStart "Claude.exe" --process-start-args "--foo bar"`,
			want:    []string{"--processStart", "Claude.exe", "--process-start-args", "--foo bar"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseWindowsCommandTokens(tt.command)
			if len(got) != len(tt.want) {
				t.Fatalf("parseWindowsCommandTokens(%q) len=%d, want %d (%v)", tt.command, len(got), len(tt.want), got)
			}
			for i := range tt.want {
				if got[i] != tt.want[i] {
					t.Fatalf("parseWindowsCommandTokens(%q)[%d] = %q, want %q", tt.command, i, got[i], tt.want[i])
				}
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

func TestShortcutRecoveryHintFromShortcut(t *testing.T) {
	t.Run("skips package-cache recovery without an explicit launcher signal", func(t *testing.T) {
		hint := shortcutRecoveryHintFromShortcut("Claude", "")
		if hint.isValid() {
			t.Fatalf("shortcutRecoveryHintFromShortcut should be invalid without launcher hints")
		}
	})

	t.Run("adds processStart executable hint when present", func(t *testing.T) {
		hint := shortcutRecoveryHintFromShortcut(
			"Anthropic launcher",
			`--processStart "Claude.exe" --process-start-args "--foo bar"`,
		)
		if !hint.isValid() {
			t.Fatalf("shortcutRecoveryHintFromShortcut returned invalid hint")
		}
		if !matchesAnyNormalizedHint("claude", hint.normalizedCandidates) {
			t.Fatalf("expected normalizedCandidates to include claude, got %v", hint.normalizedCandidates)
		}
	})

	t.Run("adds AppX shell appsfolder hints when present", func(t *testing.T) {
		hint := shortcutRecoveryHintFromShortcut(
			"Claude",
			`shell:AppsFolder\Claude_pzs8sxrjxfjjc!App`,
		)
		if !hint.isValid() {
			t.Fatalf("shortcutRecoveryHintFromShortcut returned invalid hint")
		}
		if !matchesAnyNormalizedHint("claudepzs8sxrjxfjjc", hint.normalizedCandidates) {
			t.Fatalf("expected normalizedCandidates to include package id, got %v", hint.normalizedCandidates)
		}
	})
}

func TestResolvePackageCacheExecutable(t *testing.T) {
	t.Run("finds executable in appx-style local cache tree", func(t *testing.T) {
		root := t.TempDir()
		packageDir := filepath.Join(root, "Claude_pzs8sxrjxfjjc")
		exePath := filepath.Join(
			packageDir,
			"LocalCache",
			"Roaming",
			"Claude",
			"claude-code",
			"2.1.78",
			"claude.exe",
		)
		if err := os.MkdirAll(filepath.Dir(exePath), 0o755); err != nil {
			t.Fatalf("mkdir executable directory: %v", err)
		}
		if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
			t.Fatalf("write executable: %v", err)
		}

		hint := shortcutRecoveryHintFromShortcut("Claude", `shell:AppsFolder\Claude_pzs8sxrjxfjjc!App`)
		got := resolvePackageCacheExecutable([]string{packageDir}, hint)
		if got != exePath {
			t.Fatalf("resolvePackageCacheExecutable(...) = %q, want %q", got, exePath)
		}
	})

	t.Run("matches processStart hint when display name differs", func(t *testing.T) {
		root := t.TempDir()
		packageDir := filepath.Join(root, "Claude_pzs8sxrjxfjjc")
		exePath := filepath.Join(
			packageDir,
			"LocalCache",
			"Roaming",
			"Claude",
			"app-1.0.0",
			"Claude.exe",
		)
		if err := os.MkdirAll(filepath.Dir(exePath), 0o755); err != nil {
			t.Fatalf("mkdir executable directory: %v", err)
		}
		if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
			t.Fatalf("write executable: %v", err)
		}

		hint := shortcutRecoveryHintFromShortcut(
			"Anthropic launcher",
			`--processStart "Claude.exe" --process-start-args "--foo=bar"`,
		)
		got := resolvePackageCacheExecutable([]string{packageDir}, hint)
		if got != exePath {
			t.Fatalf("resolvePackageCacheExecutable(...processStart...) = %q, want %q", got, exePath)
		}
	})

	t.Run("returns empty when no candidate executable matches hint", func(t *testing.T) {
		root := t.TempDir()
		packageDir := filepath.Join(root, "Claude_pzs8sxrjxfjjc")
		exePath := filepath.Join(
			packageDir,
			"LocalCache",
			"Roaming",
			"Claude",
			"app-1.0.0",
			"Updater.exe",
		)
		if err := os.MkdirAll(filepath.Dir(exePath), 0o755); err != nil {
			t.Fatalf("mkdir executable directory: %v", err)
		}
		if err := os.WriteFile(exePath, []byte(""), 0o644); err != nil {
			t.Fatalf("write executable: %v", err)
		}

		hint := shortcutRecoveryHintFromShortcut("Claude", `shell:AppsFolder\Claude_pzs8sxrjxfjjc!App`)
		got := resolvePackageCacheExecutable([]string{packageDir}, hint)
		if got != "" {
			t.Fatalf("resolvePackageCacheExecutable(...) = %q, want empty", got)
		}
	})
}
