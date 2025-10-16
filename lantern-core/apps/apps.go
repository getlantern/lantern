package apps

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"howett.net/plist"
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

func getBundleID(appPath string) (string, error) {
	plistPath := filepath.Join(appPath, "Contents", "Info.plist")
	file, err := os.Open(plistPath)
	if err != nil {
		return "", fmt.Errorf("unable to open plist: %w", err)
	}
	defer file.Close()

	var parsed map[string]interface{}
	decoder := plist.NewDecoder(file)
	if err := decoder.Decode(&parsed); err != nil {
		return "", fmt.Errorf("failed to decode plist: %w", err)
	}

	bundleID, ok := parsed["CFBundleIdentifier"].(string)
	if !ok {
		return "", fmt.Errorf("CFBundleIdentifier not found or invalid")
	}

	return bundleID, nil
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
			slog.Info("Visiting", "path", path)
			if err != nil || d == nil {
				return nil
			}
			if !d.IsDir() {
				return nil
			}

			for _, ex := range excludeDirs {
				if strings.HasPrefix(path, ex) {
					slog.Info("Excluding path", "path", path)
					return filepath.SkipDir
				}
			}

			base := filepath.Base(path)
			if !strings.HasSuffix(base, ".app") {
				return nil
			}
			bundleID, err := getBundleID(path)
			if err != nil {
				slog.Info("Could not find bundle ID for app", "path", path, "error", err)
				return filepath.SkipDir
			}
			key := bundleID

			if key == "" {
				key = path
			}

			if seen[bundleID] || seen[path] || seen[key] {
				slog.Info("Skipping duplicate app", "name", strings.TrimSuffix(base, ".app"), "bundleID", bundleID, "path", path)
				return filepath.SkipDir
			}

			iconPath, _ := getIconPath(path)

			slog.Info("Found app", "name", strings.TrimSuffix(base, ".app"), "bundleID", bundleID, "path", path, "icon", iconPath)
			app := &AppData{
				BundleID: bundleID,
				Name:     strings.TrimSuffix(base, ".app"),
				AppPath:  path,
				IconPath: iconPath,
			}

			if cb != nil {
				if err := cb(app); err != nil {
					slog.Debug("callback error for", "app", app.Name, "error", err)
				}
			}
			apps = append(apps, app)
			seen[bundleID] = true
			seen[path] = true
			seen[key] = true
			return filepath.SkipDir
		})
	}
	return apps
}

func defaultAppDirs() []string {
	home, _ := os.UserHomeDir()
	return []string{
		"/Applications",
		"/System/Applications",
		filepath.Join(home, "Applications"),
	}
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

var macOSExcludeDirs = []string{
	"/Applications/Contents",
	"/Applications/Library",
	"/Applications/Utilities",
}

// LoadInstalledApps fetches the app list or rescans if needed
func LoadInstalledApps(dataDir string, cb Callback) {
	dirs := defaultAppDirs()
	_, _ = LoadInstalledAppsWithDirs(dataDir, dirs, macOSExcludeDirs, cb)
}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	resourcesPath := filepath.Join(appPath, "Contents", "Resources")
	matches, err := filepath.Glob(filepath.Join(resourcesPath, "*.icns"))
	if err != nil {
		wrapped := fmt.Errorf("error globbing icons for %s: %w", appPath, err)
		slog.Error("glob error:", "error", wrapped)
		return "", wrapped
	}
	if len(matches) == 0 {
		return "", nil
	}
	return matches[0], nil
}
