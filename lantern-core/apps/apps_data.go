package apps

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`

	IconBytes []byte `json:"iconBytes,omitempty"`
}
