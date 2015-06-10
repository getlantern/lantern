// +build !windows,!darwin
package appdir

import (
	"fmt"
	"path/filepath"
	"strings"
)

func general(app string) string {
	// It is more common on Linux to expect application related directories
	// in all lowercase. The lantern wrapper also expects a lowercased
	// directory.
	return InHomeDir(fmt.Sprintf(".%s", strings.ToLower(app)))
}

func logs(app string) string {
	return filepath.Join(general(app), "logs")
}
