package apps

type AppData struct {
	Name     string `json:"name"`
	BundleID string `json:"bundleId"`
	AppPath  string `json:"appPath"`
	IconPath string `json:"iconPath"`

	// IsBrowser is true when the app is a web browser — drives the
	// split-tunnel bypass warning dialog on the Flutter side. Populated by
	// markBrowsers on Windows; on Android/macOS the platform layers
	// (AppDataHandler.kt / AppStreamHandler.swift) detect browsers instead.
	IsBrowser bool `json:"isBrowser"`

	IconBytes []byte `json:"iconBytes,omitempty"`
}
