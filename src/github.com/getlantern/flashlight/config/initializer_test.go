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

	var proxies map[string]*client.ChainedServerInfo
	var gotProxies bool
	var gotGlobal bool

	var global *Global
	proxiesDispatch := func(cfg interface{}) {
		proxies = cfg.(map[string]*client.ChainedServerInfo)
		gotProxies = true
	}
	globalDispatch := func(cfg interface{}) {
		global = cfg.(*Global)
		gotGlobal = true
	}
	Init(".", flags, &userConfig{}, proxiesDispatch, globalDispatch)

	for i := 1; i <= 400; i++ {
		if !gotGlobal || !gotProxies {
			time.Sleep(50 * time.Millisecond)
		}
	}

	// Just make sure it's legitimately reading the config.
	assert.True(t, len(global.Client.MasqueradeSets) > 1)
	assert.True(t, len(proxies) > 0)
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
