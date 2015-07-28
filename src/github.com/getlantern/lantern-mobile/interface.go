package client

// StopClientProxy stops the proxy.
func StopClientProxy() error {
	if err := defaultClient.stop(); err != nil {
		log.Debugf("Unable to stop client: %v", err)
	}
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
