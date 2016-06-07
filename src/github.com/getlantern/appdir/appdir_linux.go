// +build !windows,!darwin
package appdir

import (
	"fmt"
	"os"
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

		// TODO: Go for Android currently doesn't support Home Directory.
		// Remove as soon as this is available in the future
		dir = filepath.Join(dir, strings.ToLower(app))

		if _, err := os.Stat(dir); err != nil {
			if os.IsNotExist(err) {
				// Create log dir
				if err := os.MkdirAll(dir, 0755); err != nil {
					log.Errorf("Unable to create lantern dir at %s: %s", dir, err)
				}
			}
		}
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
