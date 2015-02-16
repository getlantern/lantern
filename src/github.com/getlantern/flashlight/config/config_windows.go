package config

import (
	"os"
	"path"
)

func platformSpecificConfigDir() string {
	return path.Join(os.Getenv("APPDATA"), "Lantern")
}
