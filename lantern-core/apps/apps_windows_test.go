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
			name: "no display",
			metadata: uninstallEntryMetadata{
				noDisplaySet: true,
				noDisplay:    1,
			},
			want: true,
		},
		{
			name: "parent key name",
			metadata: uninstallEntryMetadata{
				parentKeyName: "KB12345",
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
			name: "release type normal",
			metadata: uninstallEntryMetadata{
				releaseType: "Feature Pack",
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
