package apps

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
)

var (
	log = golog.LoggerFor("lantern.apps")

	appCache []*AppData
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

// LoadInstalledApps fetches the app list or rescans if needed
func LoadInstalledApps(cb Callback) error {

	cacheMux.RLock()
	if loaded {
		defer cacheMux.RUnlock()
		// Return cached results immediately
		return cb(appCache...)
	}
	cacheMux.RUnlock()

	return fmt.Errorf("app cache not ready yet")
}

func InitAppCache(appsPort int64) {

	// Directories to scan for installed apps
	appDirs := []string{"/Applications", "/System/Applications"}
	var apps []*AppData

	for _, dir := range appDirs {
		err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			// Only process .app bundles
			if info.IsDir() && strings.HasSuffix(info.Name(), ".app") {
				iconPath, _ := getIconPath(path)
				appData := &AppData{
					Name:     strings.TrimSuffix(info.Name(), ".app"),
					AppPath:  path,
					IconPath: iconPath,
				}

				apps = append(apps, appData)
			}
			return nil
		})
		if err != nil {
			log.Errorf("Error scanning directory: %v", err)
		}
	}

	cacheMux.Lock()
	appCache = apps
	loaded = true
	cacheMux.Unlock()

	if appsPort != 0 {
		data, err := json.Marshal(apps)
		if err != nil {
			log.Error(err)
			return
		}
		dart_api_dl.SendToPort(appsPort, string(data))
	}

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
