//go:build !windows && !darwin

package apps

const (
	appIsDir     = false
	appExtension = ""
)

func defaultAppDirs() []string { return nil }

var excludeDirs = []string{}
var excludeNames = map[string]bool{}

func getIconPath(string) (string, error)      { return "", nil }
func getIconBytes(string) ([]byte, error)     { return nil, nil }
func getAppID(appPath string) (string, error) { return appPath, nil }

func loadInstalledAppsPlatform(appDirs []string, seen map[string]bool, excludeDirs []string, cb Callback) []*AppData {
	return nil
}
