package appdir

import (
	"path/filepath"
)

func general(app string) string {
	return InHomeDir(filepath.Join("Library/Application Support", app))
}

func logs(app string) string {
	return InHomeDir(filepath.Join("Library/Logs", app))
}
