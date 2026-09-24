//go:build darwin && !ios

package apps

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

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

// bundleInfoPlist returns the bundle's Info.plist path and, for iPhone/iPad
// apps (<App>.app/Wrapper/<Inner>.app, no Contents/), the inner bundle name.
func bundleInfoPlist(appPath string) (plistPath, wrappedBundle string) {
	native := filepath.Join(appPath, "Contents", "Info.plist")
	if _, err := os.Stat(native); err == nil {
		return native, ""
	}
	// Not Glob: appPath may contain pattern characters such as "[".
	entries, _ := os.ReadDir(filepath.Join(appPath, "Wrapper"))
	for _, e := range entries {
		if !e.IsDir() || !strings.HasSuffix(e.Name(), ".app") {
			continue
		}
		plist := filepath.Join(appPath, "Wrapper", e.Name(), "Info.plist")
		if _, err := os.Stat(plist); err == nil {
			return plist, e.Name()
		}
	}
	return native, ""
}

func wrappedBundleName(appPath string) string {
	_, wrapped := bundleInfoPlist(appPath)
	return wrapped
}

func getAppID(appPath string) (string, error) {
	plistPath, _ := bundleInfoPlist(appPath)
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
