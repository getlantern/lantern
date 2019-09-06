package config

import (
	"testing"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/stretchr/testify/assert"
)

// TestInit tests initializing configs.
func TestInit(t *testing.T) {
	flags := make(map[string]interface{})
	flags["staging"] = true

	configChan := make(chan bool)

	// Note these dispatch functions will receive multiple configs -- local ones,
	// embedded ones, and remote ones.
	proxiesDispatch := func(cfg interface{}) {
		proxies := cfg.(map[string]*client.ChainedServerInfo)
		assert.True(t, len(proxies) > 0)
		configChan <- true
	}
	globalDispatch := func(cfg interface{}) {
		global := cfg.(*Global)
		assert.True(t, len(global.Client.MasqueradeSets) > 1)
		configChan <- true
	}
	Init(".", flags, &userConfig{}, proxiesDispatch, globalDispatch)

	count := 0
	for i := 0; i < 2; i++ {
		select {
		case <-configChan:
			count++
		case <-time.After(time.Second * 12):
			assert.Fail(t, "Took too long to get configs")
		}
	}
	assert.Equal(t, 2, count)
}

func TestStaging(t *testing.T) {
	flags := make(map[string]interface{})
	flags["staging"] = true

	assert.True(t, isStaging(flags))

	flags["staging"] = false

	assert.False(t, isStaging(flags))
}

// TestOverrides tests url override flags
func TestOverrides(t *testing.T) {
	urls := &chainedFrontedURLs{
		chained: "chained",
		fronted: "fronted",
	}
	flags := make(map[string]interface{})
	checkOverrides(flags, urls, "name")

	assert.Equal(t, "chained", urls.chained)
	assert.Equal(t, "fronted", urls.fronted)

	flags["cloudconfig"] = "test"
	checkOverrides(flags, urls, "name")

	assert.Equal(t, "test/name", urls.chained)
	assert.Equal(t, "fronted", urls.fronted)

	flags["frontedconfig"] = "test"
	checkOverrides(flags, urls, "name")

	assert.Equal(t, "test/name", urls.chained)
	assert.Equal(t, "test/name", urls.fronted)
}
