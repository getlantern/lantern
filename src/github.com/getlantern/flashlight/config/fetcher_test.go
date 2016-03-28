package config

import (
	"net/http"
	"testing"

	"github.com/getlantern/testify/assert"
)

//userConfig supplies user data for fetching user-specific configuration.
type userConfig struct {
}

func (uc *userConfig) GetToken() string {
	return "token"
}

func (uc *userConfig) GetUserID() int {
	return 10
}

// TestFetcher actually fetches a config file over the network.
func TestFetcher(t *testing.T) {
	// This will actually fetch the cloud config over the network.
	fetcher := &http.Client{}
	configFetcher := NewFetcher(&userConfig{}, fetcher)

	cfg := &Config{}
	cfg.ApplyDefaults()
	mutate, waitTime, err := configFetcher.pollForConfig(cfg, false)
	assert.Nil(t, err)
	assert.NotNil(t, mutate)
	assert.NotNil(t, waitTime)

	err = mutate(cfg)

	assert.Nil(t, err)
}
