//go:build darwin && !ios

package apps

import (
	"os"
	"path/filepath"
	"strings"

	"howett.net/plist"
)

type infoPlistSubset struct {
	LSUIElement      bool `plist:"LSUIElement"`
	LSBackgroundOnly bool `plist:"LSBackgroundOnly"`
}

func shouldExcludeAppBundle(appPath, rawName, bundleID string) bool {
	n := strings.ToLower(strings.TrimSpace(rawName))
	if strings.Contains(n, "updater") ||
		strings.Contains(n, "launcher") ||
		strings.Contains(n, "file handler") ||
		strings.Contains(n, "helper") {
		return true
	}

	plistPath := filepath.Join(appPath, "Contents", "Info.plist")
	f, err := os.Open(plistPath)
	if err != nil {
		return false
	}
	defer f.Close()

	var p infoPlistSubset
	if err := plist.NewDecoder(f).Decode(&p); err != nil {
		return false
	}

	return p.LSUIElement || p.LSBackgroundOnly
}
