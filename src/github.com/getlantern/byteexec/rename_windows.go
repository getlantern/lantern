package byteexec

import (
	"os"
	"path/filepath"
)

func renameExecutable(orig string) string {
	return orig + ".exe"
}

func pathForRelativeFiles() (string, error) {
	return filepath.Join(os.Getenv("APPDATA"), "byteexec"), nil
}
