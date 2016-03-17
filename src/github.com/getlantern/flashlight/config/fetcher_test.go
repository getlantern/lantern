package config

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestFetcher actually fetches a config file over the network.
func TestFetcher(t *testing.T) {
	// This will actually fetch the cloud config over the network.
	fetcher := &http.Client{}
	id := func() int {
		return 10
	}
	tok := func() string {
		return "token"
	}
	configFetcher := NewFetcher(id, tok, fetcher)

	cfg := &Config{}
	cfg.ApplyDefaults()
	mutate, waitTime, err := configFetcher.pollForConfig(cfg, false)
	assert.Nil(t, err)
	assert.NotNil(t, mutate)
	assert.NotNil(t, waitTime)

	err = mutate(cfg)

	assert.Nil(t, err)
}
