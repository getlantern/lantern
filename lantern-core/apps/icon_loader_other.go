//go:build !windows && !android && !ios

package apps

import (
	"fmt"
	"strings"
)

// LoadAppIconBytes resolves icon bytes for desktop platforms that are not Windows.
// The current desktop scan path already carries an app path we can resolve through
// the existing platform-specific getIconBytes implementation.
func LoadAppIconBytes(appPath, _ string) ([]byte, error) {
	trimmedAppPath := strings.TrimSpace(appPath)
	if trimmedAppPath == "" {
		return nil, fmt.Errorf("empty app path")
	}

	bytes, err := getIconBytes(trimmedAppPath)
	if err != nil {
		return nil, err
	}
	if len(bytes) == 0 {
		return nil, fmt.Errorf("icon bytes not available for %q", trimmedAppPath)
	}
	return bytes, nil
}
