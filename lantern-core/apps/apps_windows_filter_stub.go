//go:build !windows

package apps

func isWindowsSystemApp(exePath, name string) bool {
	return false
}
