// +build !windows,!darwin
package appdir

import (
	"fmt"
	"path/filepath"
	"runtime"
	"strings"
	"sync"

	"github.com/getlantern/golog"
)

var (
	homeDir  string
	dirMutex sync.RWMutex
	log      = golog.LoggerFor("appdir")
)

func SetHomeDir(dir string) {
	dirMutex.Lock()
	homeDir = dir
	dirMutex.Unlock()
}

func general(app string) string {
	if runtime.GOOS == "android" {
		dirMutex.RLock()
		dir := homeDir
		dirMutex.RUnlock()

		return dir
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
