package client

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	defaultClient.stop()
	return nil
}

// Getfiretweetversion returns the current build version string
func GetFireTweetVersion() string {
	return defaultClient.getFireTweetVersion()
}

// RunClientProxy creates a new client at the given address.
func RunClientProxy(listenAddr, appName string) error {
	defaultClient = newClient(listenAddr, appName)
	defaultClient.serveHTTP()
	return nil
}
