package apps

import "os"

const appExtension = ".exe"

// msg="found process path: C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
func defaultAppDirs() []string {
	return []string{
		// Get the AppData/Local path using environment variable.
		os.Getenv("LOCALAPPDATA"),
		// Get both program files paths using environment variables.
		os.Getenv("ProgramW6432"),      // Usually "C:\Program Files" on 64-bit Windows
		os.Getenv("ProgramFiles(x86)"), // Usually "C:\Program Files (x86)" on 64-bit Windows
	}
}

var excludeDirs = []string{}

var excludeNames = map[string]bool{
	"Uninstall": true,
	"Update":    true,
	"Updater":   true,
	"Install":   true,
	"Setup":     true,
	"Driver":    true,
}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	// TODO: implement for Windows
	return "", nil // errors.New("not implemented")
}

func getAppID(appPath string) (string, error) {
	return appPath, nil
}
