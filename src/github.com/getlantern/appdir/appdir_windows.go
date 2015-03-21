package appdir

import (
	"os"
	"path/filepath"
)

func general(app string) string {
	return filepath.Join(os.Getenv("APPDATA"), app)
}

func logs(app string) string {
	return filepath.Join(general(app), "logs")
}
