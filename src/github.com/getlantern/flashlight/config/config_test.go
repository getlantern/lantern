package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestStagingSetup tests to make sure our staging config flag sets the
// appropriate URLs for staging servers.
func TestStagingSetup(t *testing.T) {
	userConfig := &userConfig{}
	version := "test-version"
	flagsAsMap := make(map[string]interface{})

	configDir := ""
	stickyConfig := false
	var cfg *Config
	var err error
	cfg, err = Init(userConfig, version, configDir, stickyConfig, flagsAsMap)
	assert.Nil(t, err)

	assert.Equal(t, defaultChainedCloudConfigURL, cfg.CloudConfig)
	assert.Equal(t, defaultFrontedCloudConfigURL, cfg.FrontedCloudConfig)

	flagsAsMap["staging"] = true
	cfg, err = Init(userConfig, version, configDir, stickyConfig, flagsAsMap)
	assert.Nil(t, err)

	assert.Equal(t, "http://config-staging.getiantem.org/cloud.yaml.gz", cfg.CloudConfig)
	assert.Equal(t, "http://d33pfmbpauhmvd.cloudfront.net/cloud.yaml.gz", cfg.FrontedCloudConfig)
}

func TestMajorVersion(t *testing.T) {
	ver := "222.00.1"
	maj := majorVersion(ver)
	assert.Equal(t, "222.00", maj, "Unexpected major version")
}
