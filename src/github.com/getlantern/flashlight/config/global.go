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
	AutoUpdateCA          string
	CPUProfile            string
	MemProfile            string
	UpdateServerURL       string
	BordaReportInterval   time.Duration
	BordaSamplePercentage float64
	Client                *client.ClientConfig
	ProxiedSites          *proxiedsites.Config // List of proxied site domains that get routed through Lantern rather than accessed directly
	TrustedCAs            []*fronted.CA
}
