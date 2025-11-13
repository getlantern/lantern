package apps

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"

	"howett.net/plist"
)

const appExtension = ".app"

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

var excludeNames = map[string]bool{}

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
