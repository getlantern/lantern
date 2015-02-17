package config

func platformSpecificConfigDir() string {
	return inHomeDir("Library/Application Support/Lantern")
}
