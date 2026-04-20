//go:build windows

package apps

import (
	"fmt"
	"strings"
)

// LoadAppIconBytes resolves and renders an icon for a discovered Windows app.
// It prefers explicit icon location data (which may include a resource index),
// then falls back to the executable path.
func LoadAppIconBytes(appPath, iconPath string) ([]byte, error) {
	trimmedAppPath := strings.TrimSpace(appPath)
	trimmedIconPath := strings.TrimSpace(iconPath)

	if trimmedIconPath != "" {
		iconFile, iconIndex := parseIconLocation(trimmedIconPath)
		if iconFile != "" {
			if bytes, err := getIconBytesFromLocation(iconFile, iconIndex); err == nil && len(bytes) > 0 {
				return bytes, nil
			}
		}
	}

	if trimmedAppPath != "" {
		if bytes, err := getIconBytesFromLocation(trimmedAppPath, 0); err == nil && len(bytes) > 0 {
			return bytes, nil
		}
	}

	return nil, fmt.Errorf("unable to resolve icon bytes for appPath=%q iconPath=%q", appPath, iconPath)
}
