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

	var gotProxies bool
	var gotGlobal bool

	proxiesDispatch := func(cfg interface{}) {
		proxies := cfg.(map[string]*client.ChainedServerInfo)
		assert.True(t, len(proxies) > 0)
		gotProxies = true
	}
	globalDispatch := func(cfg interface{}) {
		global := cfg.(*Global)
		assert.True(t, len(global.Client.MasqueradeSets) > 1)
		gotGlobal = true
	}
	Init(".", flags, &userConfig{}, proxiesDispatch, globalDispatch)

	for i := 1; i <= 400; i++ {
		if !gotGlobal || !gotProxies {
			time.Sleep(50 * time.Millisecond)
		}
	}
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
