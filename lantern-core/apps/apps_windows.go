//go:build windows

package apps

import (
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/sys/windows/registry"
)

var excludeNames = map[string]bool{
	"uninstall": true,
	"update":    true,
	"updater":   true,
	"install":   true,
	"setup":     true,
	"driver":    true,
}

const (
	appIsDir     = false
	appExtension = ".exe"
)

func loadInstalledAppsPlatform(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	var out []*AppData

	// Best list: Start Menu shortcuts
	out = append(out, collectAppsFromStartMenuShortcuts(seen, cb)...)

	out = append(out, collectAppsFromUninstallRegistry(seen, cb)...)

	// Fallback: recursive app scan
	if len(out) == 0 {
		slog.Debug("no apps from start menu/registry; falling back to directory scan")
		out = append(out, scanAppDirs(appDirs, seen, excludeDirs, cb)...)
	}

	return out
}

// Reads “installed apps” entries from:
// - HKLM/HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall
// - both 64-bit + 32-bit views when possible
func collectAppsFromUninstallRegistry(seen map[string]bool, cb Callback) []*AppData {
	var out []*AppData

	type root struct {
		key   registry.Key
		path  string
		flags uint32
	}

	const uninstallPath = `Software\Microsoft\Windows\CurrentVersion\Uninstall`

	roots := []root{
		{registry.LOCAL_MACHINE, uninstallPath, registry.READ | registry.WOW64_64KEY},
		{registry.LOCAL_MACHINE, uninstallPath, registry.READ | registry.WOW64_32KEY},
		{registry.CURRENT_USER, uninstallPath, registry.READ | registry.WOW64_64KEY},
		{registry.CURRENT_USER, uninstallPath, registry.READ | registry.WOW64_32KEY},
	}

	for _, r := range roots {
		k, err := registry.OpenKey(r.key, r.path, r.flags)
		if err != nil {
			continue
		}

		names, _ := k.ReadSubKeyNames(-1)
		k.Close()

		for _, sub := range names {
			sk, err := registry.OpenKey(r.key, r.path+`\`+sub, r.flags)
			if err != nil {
				continue
			}

			displayName, _, _ := sk.GetStringValue("DisplayName")
			displayIcon, _, _ := sk.GetStringValue("DisplayIcon")
			installLoc, _, _ := sk.GetStringValue("InstallLocation")
			sk.Close()

			displayName = strings.TrimSpace(displayName)
			if displayName == "" {
				// No name usually indicates an app is “not user-facing”, so skip
				continue
			}

			exePath := pickExePath(displayIcon, installLoc)
			if exePath == "" || !strings.HasSuffix(strings.ToLower(exePath), ".exe") {
				continue
			}

			// Don’t show uninstallers/updaters
			if isExcludedName(filepathBaseNoExt(exePath)) {
				continue
			}

			appID := exePath
			keyID := normalizeKey(appID)
			keyPath := normalizeKey(exePath)
			if seen[keyID] || seen[keyPath] {
				continue
			}

			app := &AppData{
				Name:     displayName,
				BundleID: appID,
				AppPath:  exePath,
			}

			iconFile, iconIndex := parseIconLocation(displayIcon)
			if iconFile != "" {
				if b, err := getIconBytesFromLocation(iconFile, iconIndex); err == nil {
					app.IconBytes = b
				}
			}

			if cb != nil {
				cb(app)
			}
			out = append(out, app)

			seen[keyID] = true
			seen[keyPath] = true
		}
	}

	return out
}

func filepathBaseNoExt(p string) string {
	b := filepath.Base(p)
	return strings.TrimSuffix(b, filepath.Ext(b))
}

func pickExePath(displayIcon, installLoc string) string {
	if p := parseDisplayIcon(displayIcon); p != "" {
		if fileExists(p) {
			return p
		}
	}

	installLoc = strings.TrimSpace(expandPercentEnv(installLoc))
	if installLoc == "" {
		return ""
	}
	if st, err := os.Stat(installLoc); err == nil && st.IsDir() {
		entries, err := os.ReadDir(installLoc)
		if err == nil {
			for _, e := range entries {
				if e.IsDir() {
					continue
				}
				n := strings.ToLower(e.Name())
				if strings.HasSuffix(n, ".exe") {
					full := filepath.Join(installLoc, e.Name())
					return full
				}
			}
		}
	}
	return ""
}

func parseDisplayIcon(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}

	s = expandPercentEnv(s)
	s = strings.Trim(s, `"`)

	if i := strings.LastIndex(s, ","); i > 0 {
		tail := strings.TrimSpace(s[i+1:])
		if tail != "" && len(tail) <= 3 {
			s = strings.TrimSpace(s[:i])
			s = strings.Trim(s, `"`)
		}
	}

	// If DisplayIcon points to a DLL, skip it
	if !strings.HasSuffix(strings.ToLower(s), ".exe") {
		return ""
	}

	return s
}

func expandPercentEnv(s string) string {
	// replace %VAR% with os.Getenv(VAR)
	for {
		start := strings.Index(s, "%")
		if start < 0 {
			break
		}
		end := strings.Index(s[start+1:], "%")
		if end < 0 {
			break
		}
		end = start + 1 + end
		key := s[start+1 : end]
		val := os.Getenv(key)
		s = s[:start] + val + s[end+1:]
	}
	return s
}

func fileExists(p string) bool {
	if p == "" {
		return false
	}
	_, err := os.Stat(p)
	return err == nil
}

func getAppID(appPath string) (string, error) {
	return appPath, nil
}
