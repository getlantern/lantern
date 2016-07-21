package config

import (
	"os"
	"runtime"
	"testing"
	"time"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/fronted"
	"github.com/stretchr/testify/assert"
)

// TestObfuscated tests reading obfuscated global config from disk
func TestObfuscated(t *testing.T) {
	config := NewConfig("./obfuscated-global.yaml", true, "global.yaml.gz", "global.yaml", func() interface{} {
		return &Config{}
	})

	conf, err := config.Saved()
	assert.Nil(t, err)

	cfg := conf.(*Config)

	// Just make sure it's legitimately reading the config.
	assert.True(t, len(cfg.Client.MasqueradeSets) > 1)
}

// TestSaved tests reading stored proxies from disk
func TestSaved(t *testing.T) {
	cfg := NewConfig("./proxies.yaml", false, "proxies.yaml.gz", "proxies.yaml", func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	pr, err := cfg.Saved()
	assert.Nil(t, err)

	proxies := pr.(map[string]*client.ChainedServerInfo)
	chained := proxies["fallback-1.1.1.1"]
	assert.True(t, chained != nil)
	assert.Equal(t, "1.1.1.1:443", chained.Addr)
}

// TestEmbedded tests reading stored proxies from disk
func TestEmbedded(t *testing.T) {
	cfg := NewConfig("./proxies.yaml", false, "proxies.yaml.gz", "proxies.yaml", func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	pr, err := cfg.Embedded()
	assert.Nil(t, err)

	proxies := pr.(map[string]*client.ChainedServerInfo)
	assert.Equal(t, 2, len(proxies))
	for _, val := range proxies {
		assert.True(t, val != nil)
		assert.True(t, len(val.Addr) > 6)
	}
}

func TestPoll(t *testing.T) {
	fronted.ConfigureForTest(t)
	proxyChan := make(chan interface{})
	file := "./fetched-proxies.yaml"
	cfg := NewConfig(file, false, "proxies.yaml.gz", "proxies.yaml", func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	fi, err := os.Stat(file)
	assert.Nil(t, err)
	mtime := fi.ModTime()

	flags := make(map[string]interface{})
	flags["staging"] = false

	go cfg.Poll(&userConfig{}, flags, proxyChan)
	proxies := (<-proxyChan).(map[string]*client.ChainedServerInfo)
	runtime.Gosched()
	runtime.Gosched()
	runtime.Gosched()

	assert.True(t, len(proxies) > 0)
	for _, val := range proxies {
		assert.True(t, val != nil)
		assert.True(t, len(val.Addr) > 6)
	}

	for i := 1; i <= 20; i++ {
		fi, err = os.Stat(file)
		if fi.ModTime().After(mtime) {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	fi, err = os.Stat(file)
	assert.Nil(t, err)
	assert.True(t, fi.ModTime().After(mtime))

}
