package apps

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
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
}

type Callback func(...*AppData) error

func loadCacheFromFile(dataDir string) ([]*AppData, error) {
	path := filepath.Join(dataDir, cacheFilename)
	data, err := os.ReadFile(path)
	if err != nil {
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
	b, err := json.Marshal(apps)
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
	slog.Debug("Saved apps cache to", "path", path)
	return nil
}

// scanAppDirs walks the provided app directories and emits AppData for any *.app bundles
func scanAppDirs(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	apps := []*AppData{}
	for _, dir := range appDirs {
		info, err := os.Stat(dir)
		if err != nil || !info.IsDir() {
			continue
		}

		_ = filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
			//slog.Info("Visiting", "path", path)
			if err != nil || d == nil {
				slog.Info("Error accessing path", "path", path, "error", err)
				return nil
			}
			//if !d.IsDir() {
			//	slog.Info("Not a directory")
			//	return nil
			//}

			for _, ex := range excludeDirs {
				if strings.HasPrefix(path, ex) {
					slog.Info("Excluding path", "path", path)
					return filepath.SkipDir
				}
			}

			base := filepath.Base(path)
			if !strings.HasSuffix(base, appExtension) {
				//slog.Info("Not a potential app", "path", path)
				return nil
			}
			//slog.Info("Found potential app", "path", path)
			appID, err := getAppID(path)
			if err != nil {
				//slog.Info("Could not find bundle ID for app", "path", path, "error", err)
				return filepath.SkipDir
			}

			name := capitalizeFirstLetter(strings.TrimSuffix(base, appExtension))
			if excludeNames[name] {
				slog.Info("Excluding app by name", "name", name, "path", path)
				return filepath.SkipDir
			}

			if seen[appID] || seen[path] || seen[name] {
				slog.Info("Skipping duplicate app", "name", strings.TrimSuffix(base, appExtension), "appID", appID, "path", path)
				return filepath.SkipDir
			}

			iconPath, _ := getIconPath(path)
			slog.Info("Found app", "name", name, "appID", appID, "path", path, "icon", iconPath)
			app := &AppData{
				BundleID: appID,
				Name:     name,
				AppPath:  path,
				IconPath: iconPath,
			}

			if cb != nil {
				if err := cb(app); err != nil {
					slog.Debug("callback error for", "app", app.Name, "error", err)
				}
			}
			apps = append(apps, app)
			seen[appID] = true
			seen[path] = true
			seen[name] = true
			return filepath.SkipDir
		})
	}
	return apps
}

func capitalizeFirstLetter(s string) string {
	if s == "" {
		return "" // Handle empty string case
	}

	// Decode the first rune and its size
	r, size := utf8.DecodeRuneInString(s)

	// If the rune is an error (e.g., invalid UTF-8), return the original string
	if r == utf8.RuneError {
		return s
	}

	// Capitalize the first rune and concatenate with the rest of the string
	return string(unicode.ToUpper(r)) + s[size:]
}

// LoadInstalledAppsWithDirs scans the provided appDirs for installed applications, using dataDir for caching.
// It invokes the Callback cb for each discovered app. Returns the number of apps found and an error, if any.
func LoadInstalledAppsWithDirs(dataDir string, appDirs []string, excludeDirs []string, cb Callback) (int, error) {
	seen := make(map[string]bool)

	if cached, err := loadCacheFromFile(dataDir); err == nil {
		for _, app := range cached {
			if app == nil {
				continue
			}
			if cb != nil {
				_ = cb(app)
			}
			if app.BundleID != "" {
				seen[app.BundleID] = true
			}
			if app.AppPath != "" {
				seen[app.AppPath] = true
			}
			if app.Name != "" {
				seen[app.Name] = true
			}
		}
	}

	apps := scanAppDirs(appDirs, seen, excludeDirs, cb)
	if err := saveCacheToFile(dataDir, apps...); err != nil {
		slog.Error("Unable to save apps cache:", "error", err)
		return len(apps), err
	}
	slog.Debug("App scan completed.", "count", len(apps))
	return len(apps), nil
}

// LoadInstalledApps fetches the app list or rescans if needed
func LoadInstalledApps(dataDir string, cb Callback) {
	dirs := defaultAppDirs()
	_, _ = LoadInstalledAppsWithDirs(dataDir, dirs, excludeDirs, cb)
}
