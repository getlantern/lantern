package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/getlantern/lantern-outline/lantern-core/dart_api_dl"
)

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`
}

func sendAppData() {
	appsPort, err := servicePort("apps")
	if err != nil {
		return
	}
	getAppsData(appsPort)
}

func getInstalledApps() ([]AppData, error) {
	cmd := exec.Command(
		"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
		"-dump",
	)

	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return nil, fmt.Errorf("failed to run lsregister: %w", err)
	}

	// Regex to match app bundles
	appRegex := regexp.MustCompile(`^\s*path:\s*(.*?\.app)\s*$`)
	bundleRegex := regexp.MustCompile(`^\s*bundleID:\s*(.*?)\s*$`)

	var apps []AppData
	var currentApp AppData

	lines := strings.Split(out.String(), "\n")
	for _, line := range lines {
		if matches := appRegex.FindStringSubmatch(line); matches != nil {
			if currentApp.AppPath != "" {
				apps = append(apps, currentApp)
			}
			currentApp = AppData{
				AppPath:  matches[1],
				IconPath: fmt.Sprintf("%s/Contents/Resources/AppIcon.icns", matches[1]),
			}
			parts := strings.Split(matches[1], "/")
			currentApp.Name = strings.TrimSuffix(parts[len(parts)-1], ".app")
		} else if matches := bundleRegex.FindStringSubmatch(line); matches != nil {
			currentApp.BundleID = matches[1]
		}
	}

	// Add last app
	if currentApp.AppPath != "" {
		apps = append(apps, currentApp)
	}

	return apps, nil
}

func getAppsData(appsPort int64) error {

	// Directories to scan for installed apps
	appDirs := []string{"/Applications", "/System/Applications"}

	for _, dir := range appDirs {
		err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			// Only process .app bundles
			if info.IsDir() && strings.HasSuffix(info.Name(), ".app") {

				iconPath := getIconPath(path)
				appData := AppData{Name: info.Name(), IconPath: iconPath}
				data, err := json.Marshal(&appData)
				if err != nil {
					return err
				}
				dart_api_dl.SendToPort(appsPort, string(data))
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
func getIconPath(appPath string) string {
	iconPath := ""
	resourcesPath := filepath.Join(appPath, "Contents", "Resources")
	err := filepath.Walk(resourcesPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if strings.HasSuffix(info.Name(), ".icns") {
			// Found icon file
			log.Debugf("→ Found icon:", path)
			iconPath = path
			return nil
		}
		return nil
	})
	if err != nil {
		log.Debugf("Error finding icon for %s:%v", appPath, err)
		return ""
	}
	return iconPath
}
