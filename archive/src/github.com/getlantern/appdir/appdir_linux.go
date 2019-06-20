// +build !windows,!darwin
package appdir

import (
	"fmt"
	"path/filepath"
	"runtime"
	"strings"
)

func general(app string) string {
	if runtime.GOOS == "android" {
		// TODO: Go for Android currently doesn't support Home Directory.
		// Remove as soon as this is available in the future
		return fmt.Sprintf(".%s", strings.ToLower(app))
	} else {
		// It is more common on Linux to expect application related directories
		// in all lowercase. The lantern wrapper also expects a lowercased
		// directory.
		return InHomeDir(fmt.Sprintf(".%s", strings.ToLower(app)))
	}
}

func logs(app string) string {
	return filepath.Join(general(app), "logs")
}
