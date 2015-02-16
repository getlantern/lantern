// +build !windows,!darwin

package config

func platformSpecificConfigDir() string {
	return inHomeDir(".Lantern")
}
