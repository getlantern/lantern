package config

import (
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/fronted"
	"github.com/getlantern/proxiedsites"
)

// Global contains general configuration for Lantern either set globally via
// the cloud, in command line flags, or in local customizations during
// development.
type Global struct {
	Version       int
	CloudConfigCA string

	// AutoUpdateCA is the CA key to pin for auto-updates.
	AutoUpdateCA           string
	UpdateServerURL        string
	BordaReportInterval    time.Duration
	BordaSamplePercentage  float64
	LogglySamplePercentage float64
	Client                 *client.ClientConfig

	// ProxiedSites are domains that get routed through Lantern rather than accessed directly.
	ProxiedSites *proxiedsites.Config

	// TrustedCAs are trusted CAs for domain fronting domains only.
	TrustedCAs []*fronted.CA
}

// applyFlags updates this config from any command-line flags that were passed
// in.
func (cfg *Global) applyFlags(flags map[string]interface{}) error {
	if cfg.Client == nil {
		cfg.Client = &client.ClientConfig{}
	}

	var visitErr error

	// Visit all flags that have been set and copy to config
	for key, value := range flags {
		switch key {
		// General
		case "cloudconfigca":
			cfg.CloudConfigCA = value.(string)
		case "borda-report-interval":
			cfg.BordaReportInterval = value.(time.Duration)
		case "borda-sample-percentage":
			cfg.BordaSamplePercentage = value.(float64)
		case "loggly-sample-percentage":
			cfg.LogglySamplePercentage = value.(float64)
		}
	}
	if visitErr != nil {
		return visitErr
	}

	return nil
}
