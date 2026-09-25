package apps

type AppData struct {
	Name      string `json:"name"`
	BundleID  string `json:"bundleId"`
	AppPath   string `json:"appPath"`
	IconPath  string `json:"iconPath"`
	IsBrowser bool   `json:"isBrowser"`
	// WrappedBundle is the inner bundle name (<App>.app/Wrapper/<this>) for
	// iPhone and iPad apps on macOS; empty for native bundles.
	WrappedBundle string `json:"wrappedBundle,omitempty"`
	IconBytes     []byte `json:"iconBytes,omitempty"`
}
