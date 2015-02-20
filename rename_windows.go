package byteexec

import (
	"os"
	"path"
)

func renameExecutable(orig string) string {
	return orig + ".exe"
}

func pathForRelativeFiles() (string, error) {
	return path.Join(os.Getenv("APPDATA"), "byteexec"), nil
}
