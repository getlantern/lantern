//go:build !darwin

package apps

func shouldExcludeAppBundle(appPath string, rawName string, bundleID string) bool { return false }
