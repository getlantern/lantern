// +build !windows,!darwin

package appdir

import (
	"fmt"
	"path/filepath"
)

func general(app string) string {
	return InHomeDir(fmt.Sprintf(".%s", app))
}

func logs(app string) string {
	return filepath.Join(general(app), "logs")
}
