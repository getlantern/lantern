package config

import (
	"embed"
	_ "embed"

	"github.com/getlantern/radiance/config"
	"google.golang.org/protobuf/encoding/protojson"
)

var (
	//go:embed local.json
	f embed.FS
)

// Load configuration file
func LoadConfig() (*config.Config, error) {
	var cfg config.Config
	data, err := f.ReadFile("local.json")
	if err != nil {
		return nil, err
	}
	err = protojson.Unmarshal(data, &cfg)
	return &cfg, err
}
