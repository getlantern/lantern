// +build !windows,!darwin

package byteexec

func renameExecutable(orig string) string {
	return orig
}

func pathForRelativeFiles() (string, error) {
	return inHomeDir(".byteexec")
}
