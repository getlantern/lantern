// +build !windows

package byteexec

func renameExecutable(orig string) string {
	return orig
}

func pathForRelativeFiles() (string, error) {
	return inHomeDir("Library/Application Support/byteexec")
}
