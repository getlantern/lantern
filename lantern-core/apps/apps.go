package apps

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/getlantern/golog"
)

var (
	log = golog.LoggerFor("lantern.apps")
)

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`
}

type Callback func(*AppData) error

func LoadInstalledApps(cb Callback) error {
	// Directories to scan for installed apps
	appDirs := []string{"/Applications", "/System/Applications"}

	for _, dir := range appDirs {
		err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			// Only process .app bundles
			if info.IsDir() && strings.HasSuffix(info.Name(), ".app") {
				iconPath, _ := getIconPath(path)
				appData := AppData{Name: info.Name(), IconPath: iconPath}
				return cb(&appData)
			}
			return nil
		})
		if err != nil {
			return fmt.Errorf("error scanning directory: %v", err)
		}
	}

	return nil
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
