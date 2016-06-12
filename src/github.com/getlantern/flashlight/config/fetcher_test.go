package config

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

//userConfig supplies user data for fetching user-specific configuration.
type userConfig struct {
}

func (uc *userConfig) GetToken() string {
	return "token"
}

func (uc *userConfig) GetUserID() int64 {
	return 10
}

// TestFetcher actually fetches a config file over the network.
func TestFetcher(t *testing.T) {
	// This will actually fetch the cloud config over the network.
	rt := &http.Transport{}
	flags := make(map[string]interface{})
	configFetcher := NewFetcher(&userConfig{}, rt, flags)

	cfg := &Config{}
	cfg.ApplyDefaults()
	mutate, waitTime, err := configFetcher.pollForConfig(cfg)
	assert.NoError(t, err)
	assert.NotNil(t, mutate)
	assert.NotNil(t, waitTime)

	err = mutate(cfg)

	assert.Nil(t, err)
}

// TestStagingSetup tests to make sure our staging config flag sets the
// appropriate URLs for staging servers.
func TestStagingSetup(t *testing.T) {
	flags := make(map[string]interface{})
	flags["staging"] = false

	rt := &http.Transport{}

	var fetch *fetcher
	fetch = NewFetcher(&userConfig{}, rt, flags).(*fetcher)

	assert.Equal(t, defaultChainedCloudConfigURL, fetch.chainedURL)
	assert.Equal(t, defaultFrontedCloudConfigURL, fetch.frontedURL)

	// Test that setting the URLs to use from the command line still works.
	flags["cloudconfig"] = "testconfig"
	flags["frontedconfig"] = "testconfig"
	fetch = NewFetcher(&userConfig{}, rt, flags).(*fetcher)

	assert.Equal(t, "testconfig", fetch.chainedURL)
	assert.Equal(t, "testconfig", fetch.frontedURL)

	// Blank flags should mean we use the default
	flags["cloudconfig"] = ""
	flags["frontedconfig"] = ""
	fetch = NewFetcher(&userConfig{}, rt, flags).(*fetcher)

	assert.Equal(t, defaultChainedCloudConfigURL, fetch.chainedURL)
	assert.Equal(t, defaultFrontedCloudConfigURL, fetch.frontedURL)

	flags["staging"] = true
	fetch = NewFetcher(&userConfig{}, rt, flags).(*fetcher)
	assert.Equal(t, "http://config-staging.getiantem.org/cloud.yaml.gz", fetch.chainedURL)
	assert.Equal(t, "http://d33pfmbpauhmvd.cloudfront.net/cloud.yaml.gz", fetch.frontedURL)
}
