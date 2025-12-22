//go:build darwin && !ios

package apps

import (
	"fmt"
	"os"
	"path/filepath"

	"howett.net/plist"
)

const (
	appIsDir     = true
	appExtension = ".app"
)

var excludeNames = map[string]bool{}

func defaultAppDirs() []string {
	home, _ := os.UserHomeDir()
	return []string{
		"/Applications",
		"/System/Applications",
		filepath.Join(home, "Applications"),
	}
}

var excludeDirs = []string{
	"/Applications/Contents",
	"/Applications/Library",
	"/Applications/Utilities",
}

func loadInstalledAppsPlatform(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	return scanAppDirs(appDirs, seen, excludeDirs, cb)
}

func getAppID(appPath string) (string, error) {
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
