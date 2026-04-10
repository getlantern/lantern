//go:build windows

package apps

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsWindowsSystemApp(t *testing.T) {
	t.Setenv("WINDIR", `C:\Windows`)

	tests := []struct {
		name    string
		exePath string
		appName string
		want    bool
	}{
		{
			name:    "system32 path",
			exePath: `C:\Windows\System32\svchost.exe`,
			appName: "svchost",
			want:    true,
		},
		{
			name:    "syswow64 path",
			exePath: `C:\Windows\SysWOW64\taskhostw.exe`,
			appName: "taskhostw",
			want:    true,
		},
		{
			name:    "winsxs path",
			exePath: `C:\Windows\WinSxS\amd64_component\RuntimeBroker.exe`,
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
