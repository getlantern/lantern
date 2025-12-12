//go:build windows

package apps

import (
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-ole/go-ole"
	"github.com/go-ole/go-ole/oleutil"
)

func collectAppsFromStartMenuShortcuts(seen map[string]bool, cb Callback) []*AppData {
	startDirs := windowsStartMenuDirs()
	var out []*AppData

	_ = ole.CoInitializeEx(0, ole.COINIT_APARTMENTTHREADED)
	defer ole.CoUninitialize()

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

			// Name: shortcut file name is usually the user-facing display name
			name := strings.TrimSuffix(d.Name(), ".lnk")
			name = strings.TrimSpace(name)
			if name == "" {
				name = filepathBaseNoExt(targetExe)
			}

			// Icon extraction (PNG bytes)
			var iconBytes []byte
			if iconFile != "" {
				if b, err := getIconBytesFromLocation(iconFile, iconIndex); err == nil {
					iconBytes = b
				}
			} else {
				// fallback: use target exe
				if b, err := getIconBytesFromLocation(targetExe, 0); err == nil {
					iconBytes = b
				}
			}

			app := &AppData{
				Name:      name,
				BundleID:  targetExe, // your Windows “ID”
				AppPath:   targetExe,
				IconPath:  "",
				IconBytes: iconBytes,
			}

			if cb != nil {
				_ = cb(app)
			}

			out = append(out, app)
			seen[keyPath] = true

			return nil
		})
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
