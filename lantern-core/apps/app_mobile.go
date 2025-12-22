// apps_mobile.go
//go:build android || ios

package apps

type Callback func(...*AppData) error

// LoadInstalledApps scans for installed apps (and may return cached results first)
func LoadInstalledApps(dataDir string, cb Callback) error {
	return nil

}
