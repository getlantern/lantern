package apps

const appExtension = ".exe"

func defaultAppDirs() []string {
	return []string{}
}

var excludeDirs = []string{}

var excludeNames = map[string]bool{}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	return "", nil
}

func getAppID(appPath string) (string, error) {
	return appPath, nil
}
