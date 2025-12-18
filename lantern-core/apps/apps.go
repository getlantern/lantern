package apps

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"unicode"
	"unicode/utf8"
)

const cacheFilename = "apps_cache.json"

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`

	IconBytes []byte `json:"-"`
}

type Callback func(...*AppData) error

func loadCacheFromFile(dataDir string) ([]*AppData, error) {
	path := filepath.Join(dataDir, cacheFilename)
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var cached []*AppData
	if err := json.Unmarshal(data, &cached); err != nil {
		return nil, err
	}

	return cached, nil
}

func saveCacheToFile(dataDir string, apps ...*AppData) error {
	if err := os.MkdirAll(dataDir, 0o755); err != nil {
		return fmt.Errorf("creating data dir: %w", err)
	}
	path := filepath.Join(dataDir, cacheFilename)

	// avoid caching IconBytes
	stripped := make([]*AppData, 0, len(apps))
	for _, a := range apps {
		if a == nil {
			continue
		}
		cp := *a
		cp.IconBytes = nil
		stripped = append(stripped, &cp)
	}

	b, err := json.Marshal(stripped)
	if err != nil {
		return fmt.Errorf("marshal cache: %w", err)
	}

	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return fmt.Errorf("write tmp cache: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		return fmt.Errorf("rename cache: %w", err)
	}

	slog.Debug("Saved apps cache", "path", path, "count", len(stripped))
	return nil
}

func normalizeKey(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	if runtime.GOOS == "windows" {
		s = strings.ToLower(s)
	}
	return s
}

// scanAppDirs walks the provided app directories and emits AppData for any *.app bundles
func scanAppDirs(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	var apps []*AppData

	for _, dir := range appDirs {
		dir = strings.TrimSpace(dir)
		if dir == "" {
			continue
		}

		info, err := os.Stat(dir)
		if err != nil || !info.IsDir() {
			continue
		}

		_ = filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
			if err != nil || d == nil {
				slog.Debug("walk error", "path", path, "error", err)
				return nil
			}

			for _, ex := range excludeDirs {
				if ex == "" {
					continue
				}
				p := path
				e := ex
				if runtime.GOOS == "windows" {
					p = strings.ToLower(p)
					e = strings.ToLower(e)
				}
				if strings.HasPrefix(p, e) {
					return filepath.SkipDir
				}
			}

			base := filepath.Base(path)
			if !strings.HasSuffix(strings.ToLower(base), strings.ToLower(appExtension)) {
				return nil
			}

			if appIsDir && !d.IsDir() {
				return nil
			}
			if !appIsDir && d.IsDir() {
				return nil
			}

			appID, err := getAppID(path)
			if err != nil {
				return nil
			}

			rawName := strings.TrimSuffix(base, appExtension)
			if isExcludedName(rawName) {
				return nil
			}

			keyID := normalizeKey(appID)
			keyPath := normalizeKey(path)
			keyName := normalizeKey(rawName)

			if seen[keyID] || seen[keyPath] || (runtime.GOOS != "windows" && seen[keyName]) {
				return nil
			}

			iconPath, _ := getIconPath(path)

			var iconBytes []byte
			if b, err := getIconBytes(path); err == nil {
				iconBytes = b
			}

			app := &AppData{
				BundleID:  appID,
				Name:      humanizeName(rawName),
				AppPath:   path,
				IconPath:  iconPath,
				IconBytes: iconBytes,
			}

			if cb != nil {
				if err := cb(app); err != nil {
					slog.Debug("apps callback returned error", "app", app.Name, "error", err)
				}
			}

			apps = append(apps, app)

			seen[keyID] = true
			seen[keyPath] = true
			if runtime.GOOS != "windows" {
				seen[keyName] = true
			}

			if appIsDir {
				return filepath.SkipDir
			}
			return nil
		})
	}

	return apps
}

func isExcludedName(name string) bool {
	n := strings.ToLower(strings.TrimSpace(name))
	n = strings.TrimSuffix(n, strings.ToLower(appExtension))
	n = strings.Trim(n, ".-_ ")
	return excludeNames[n]
}

func humanizeName(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	r, size := utf8.DecodeRuneInString(s)
	if r == utf8.RuneError {
		return s
	}
	return string(unicode.ToUpper(r)) + s[size:]
}

// LoadInstalledApps scans for installed apps (and may return cached results first)
func LoadInstalledApps(dataDir string, cb Callback) {
	dirs := defaultAppDirs()
	LoadInstalledAppsWithDirs(dataDir, dirs, excludeDirs, cb)
}

// LoadInstalledAppsWithDirs scans appDirs, emitting cached items first (if present),
// then newly discovered ones. It returns the count of newly discovered apps
func LoadInstalledAppsWithDirs(dataDir string, appDirs []string, excludeDirs []string, cb Callback) (int, error) {
	seen := make(map[string]bool)

	if cached, err := loadCacheFromFile(dataDir); err == nil {
		for _, app := range cached {
			if app == nil {
				continue
			}
			if cb != nil {
				cb(app)
			}
			if app.BundleID != "" {
				seen[normalizeKey(app.BundleID)] = true
			}
			if app.AppPath != "" {
				seen[normalizeKey(app.AppPath)] = true
			}
			if app.Name != "" {
				// on non-windows scanAppDirs also dedups by name
				seen[normalizeKey(app.Name)] = true
			}
		}
	}

	found := loadInstalledAppsPlatform(appDirs, seen, excludeDirs, cb)

	if err := saveCacheToFile(dataDir, found...); err != nil {
		slog.Error("unable to save apps cache", "error", err)
		return len(found), err
	}
	return len(found), nil
}
