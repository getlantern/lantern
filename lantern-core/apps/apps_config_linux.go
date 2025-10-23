package apps

import "errors"

const appExtension = ".exe"

func defaultAppDirs() []string {
	return []string{
		"C:\\Program Files",
	}
}

var excludeDirs = []string{}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	return "", errors.New("Not implemented")
}

func getAppID(appPath string) (string, error) {
	return "", errors.New("Not implemented")
}
