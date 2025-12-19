//go:build windows

package apps

import (
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"

	"github.com/go-ole/go-ole"
	"github.com/go-ole/go-ole/oleutil"
	"golang.org/x/sys/windows/registry"
)

var excludeDirs = []string{
	os.Getenv("WINDIR"),
	// already handled via shortcuts scan
	// filepath.Join(os.Getenv("ProgramData"), "Microsoft", "Windows", "Start Menu"),
	// maybe skip common package caches
	// filepath.Join(os.Getenv("LOCALAPPDATA"), "Packages"),
}

func defaultAppDirs() []string {
	return []string{
		os.Getenv("LOCALAPPDATA"),
		os.Getenv("ProgramW6432"),
		os.Getenv("ProgramFiles"),
		os.Getenv("ProgramFiles(x86)"),
	}
}

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

// loadInstalledAppsPlatform returns a list of installed applications for Windows
// Discovery order:
//  1. Start Menu shortcuts: the best “user-facing apps” list
//  2. Uninstall registry entries: catches apps that don’t have Start Menu shortcuts
//  3. Fallback directory scan
func loadInstalledAppsPlatform(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	var out []*AppData

	out = append(out, collectAppsFromStartMenuShortcuts(seen, cb)...)

	out = append(out, collectAppsFromUninstallRegistry(seen, cb)...)

	// Fallback: recursive app scan
	if len(out) == 0 {
		slog.Debug("no apps from start menu/registry; falling back to directory scan")
		out = append(out, scanAppDirs(appDirs, seen, excludeDirs, cb)...)
	}

	return out
}

func windowsStartMenuDirs() []string {
	appdata := os.Getenv("APPDATA")
	programData := os.Getenv("ProgramData")

	return []string{
		filepath.Join(appdata, "Microsoft", "Windows", "Start Menu", "Programs"),
		filepath.Join(programData, "Microsoft", "Windows", "Start Menu", "Programs"),
	}
}

// collectAppsFromStartMenuShortcuts enumerates apps by walking Start Menu shortcut files (*.lnk)
func collectAppsFromStartMenuShortcuts(seen map[string]bool, cb Callback) []*AppData {
	startDirs := windowsStartMenuDirs()
	var out []*AppData

	runtime.LockOSThread()
	defer runtime.UnlockOSThread()

	inited := false
	if err := ole.CoInitializeEx(0, ole.COINIT_APARTMENTTHREADED); err != nil {
		// If COM is already initialized in a different mode, we can often still proceed
		if !isRPCChangedMode(err) {
			return out
		}
	} else {
		inited = true
	}
	if inited {
		defer ole.CoUninitialize()
	}

	wshObj, err := oleutil.CreateObject("WScript.Shell")
	if err != nil {
		slog.Debug("WScript.Shell not available", "err", err)
		return out
	}
	defer wshObj.Release()

	wsh, err := wshObj.QueryInterface(ole.IID_IDispatch)
	if err != nil {
		return out
	}
	defer wsh.Release()

	for _, root := range startDirs {
		root = strings.TrimSpace(root)
		if root == "" {
			continue
		}
		if st, err := os.Stat(root); err != nil || !st.IsDir() {
			continue
		}

		_ = filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
			if err != nil || d == nil {
				return nil
			}
			if d.IsDir() {
				return nil
			}
			if !strings.HasSuffix(strings.ToLower(d.Name()), ".lnk") {
				return nil
			}

			targetExe, iconFile, iconIndex := resolveLnkViaWScript(wsh, p)

			// Many Start Menu links point to non-exe targets
			// For split tunneling we only support process path, so skip non-exe
			if targetExe == "" || !strings.HasSuffix(strings.ToLower(targetExe), ".exe") {
				return nil
			}

			if isExcludedName(filepathBaseNoExt(targetExe)) {
				return nil
			}

			keyPath := normalizeKey(targetExe)
			if seen[keyPath] {
				return nil
			}

			name := strings.TrimSpace(strings.TrimSuffix(d.Name(), ".lnk"))
			if name == "" {
				name = filepathBaseNoExt(targetExe)
			}

			var iconBytes []byte
			// Prefer explicit IconLocation; fall back to exe
			if iconFile != "" {
				if b, err := getIconBytesFromLocation(iconFile, iconIndex); err == nil {
					iconBytes = b
				}
			}
			if iconBytes == nil {
				if b, err := getIconBytesFromLocation(targetExe, 0); err == nil {
					iconBytes = b
				}
			}

			app := &AppData{
				Name:      name,
				BundleID:  targetExe,
				AppPath:   targetExe,
				IconPath:  "",
				IconBytes: iconBytes,
			}

			if cb != nil {
				cb(app)
			}
			out = append(out, app)
			seen[keyPath] = true
			return nil
		})
	}

	return out
}

// isRPCChangedMode reports whether err is RPC_E_CHANGED_MODE
func isRPCChangedMode(err error) bool {
	if err == nil {
		return false
	}
	oe, ok := err.(*ole.OleError)
	if !ok || oe == nil {
		return false
	}

	// ole.OleError.Code() returns the HRESULT
	const rpcEChangedMode = 0x80010106
	return uint32(oe.Code()) == rpcEChangedMode
}

func resolveLnkViaWScript(wsh *ole.IDispatch, lnkPath string) (targetExe string, iconFile string, iconIndex int) {
	v, err := oleutil.CallMethod(wsh, "CreateShortcut", lnkPath)
	if err != nil {
		return "", "", 0
	}
	sc := v.ToIDispatch()
	defer sc.Release()

	tp, _ := oleutil.GetProperty(sc, "TargetPath")
	il, _ := oleutil.GetProperty(sc, "IconLocation")

	targetExe = strings.TrimSpace(tp.ToString())
	iconLoc := strings.TrimSpace(il.ToString())

	iconFile, iconIndex = parseIconLocation(iconLoc)
	return targetExe, iconFile, iconIndex
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

	// strip ",<index>"
	if i := strings.LastIndex(s, ","); i > 0 {
		tail := strings.TrimSpace(s[i+1:])
		if tail != "" && len(tail) <= 5 {
			if _, err := strconv.Atoi(tail); err == nil {
				s = strings.TrimSpace(strings.Trim(s[:i], `"`))
			}
		}
	}

	ext := strings.ToLower(filepath.Ext(s))
	switch ext {
	case ".exe", ".dll", ".ico":
		return s
	default:
		return ""
	}
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
