package apps

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/getlantern/golog"
	"howett.net/plist"
)

var (
	log = golog.LoggerFor("lantern.apps")

	cacheMux sync.RWMutex
	loaded   bool
)

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`
}

type Callback func(...*AppData) error

func loadCacheFromFile(dataDir string) ([]*AppData, error) {
	path := filepath.Join(dataDir, "apps_cache.json")
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

func saveCacheToFile(dataDir string, apps ...*AppData) {
	path := filepath.Join(dataDir, "apps_cache.json")
	data, _ := json.Marshal(apps)
	if err := os.WriteFile(path, data, 0644); err != nil {
		log.Errorf("Unable to save apps cache: %v", err)
		return
	}
	log.Debugf("Saved apps cache to %s", path)
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
	err = decoder.Decode(&parsed)
	if err != nil {
		return "", fmt.Errorf("failed to decode plist: %w", err)
	}

	bundleID, ok := parsed["CFBundleIdentifier"].(string)
	if !ok {
		return "", fmt.Errorf("CFBundleIdentifier not found or invalid")
	}

	return bundleID, nil
}

func scanAppDirs(appDirs []string, seen map[string]bool, cb Callback) []*AppData {
	var apps []*AppData
	for _, dir := range appDirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			continue
		}
		err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil || !info.IsDir() || !strings.HasSuffix(info.Name(), ".app") {
				return nil
			}
			bundleID, _ := getBundleID(path)
			key := bundleID

			if key == "" {
				key = path
			}

			if _, exists := seen[bundleID]; exists {
				return nil
			} else if _, exists := seen[path]; exists {
				return nil
			}

			iconPath, _ := getIconPath(path)
			app := &AppData{
				Name:     strings.TrimSuffix(info.Name(), ".app"),
				AppPath:  path,
				IconPath: iconPath,
			}

			cb(app)
			log.Debugf("Adding %s to app cache", app.BundleID)
			apps = append(apps, app)
			seen[key] = true
			return nil
		})
		if err != nil {
			log.Errorf("Error walking directory %s: %v", dir, err)
		}
	}
	return apps
}

// LoadInstalledApps fetches the app list or rescans if needed
func LoadInstalledApps(dataDir string, cb Callback) {
	// Directories to scan for installed apps
	appDirs := []string{"/Applications" /*, "/System/Applications"*/}

	seen := make(map[string]bool)

	if cached, err := loadCacheFromFile(dataDir); err == nil {
		for _, app := range cached {
			seen[app.AppPath] = true
			cb(app)
		}
	}
	apps := scanAppDirs(appDirs, seen, cb)

	cacheMux.Lock()
	loaded = true
	saveCacheToFile(dataDir, apps...)
	cacheMux.Unlock()

	log.Debugf("App scan completed. %d apps found.", len(apps))

}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	iconPath := ""
	resourcesPath := filepath.Join(appPath, "Contents", "Resources")
	err := filepath.Walk(resourcesPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if strings.HasSuffix(info.Name(), ".icns") {
			// Found icon file
			iconPath = path
			return nil
		}
		return nil
	})
	if err != nil {
		err = fmt.Errorf("error finding icon for %s:%v", appPath, err)
		log.Error(err)
		return "", err
	}
	return iconPath, nil
}
