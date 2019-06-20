package config

import (
	"os"
	"testing"
	"time"

	"github.com/getlantern/fronted"
	"github.com/stretchr/testify/assert"

	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config/generated"
)

// TestObfuscated tests reading obfuscated global config from disk
func TestObfuscated(t *testing.T) {
	config := newConfig("./obfuscated-global.yaml", true, func() interface{} {
		return &Global{}
	})

	conf, err := config.saved()
	assert.Nil(t, err)

	cfg := conf.(*Global)

	// Just make sure it's legitimately reading the config.
	assert.True(t, len(cfg.Client.MasqueradeSets) > 1)
}

// TestSaved tests reading stored proxies from disk
func TestSaved(t *testing.T) {
	cfg := newConfig("./test-proxies.yaml", false, func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	pr, err := cfg.saved()
	assert.Nil(t, err)

	proxies := pr.(map[string]*client.ChainedServerInfo)
	chained := proxies["fallback-1.1.1.1"]
	assert.True(t, chained != nil)
	assert.Equal(t, "1.1.1.1:443", chained.Addr)
}

// TestEmbedded tests reading stored proxies from disk
func TestEmbedded(t *testing.T) {
	cfg := newConfig("./test-proxies.yaml", false, func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	pr, err := cfg.embedded(generated.EmbeddedProxies, "proxies.yaml")
	assert.Nil(t, err)

	proxies := pr.(map[string]*client.ChainedServerInfo)
	assert.Equal(t, 2, len(proxies))
	for _, val := range proxies {
		assert.True(t, val != nil)
		assert.True(t, len(val.Addr) > 6)
	}
}

func TestPollProxies(t *testing.T) {
	fronted.ConfigureForTest(t)
	proxyChan := make(chan interface{})
	file := "./fetched-proxies.yaml"
	cfg := newConfig(file, false, func() interface{} {
		return make(map[string]*client.ChainedServerInfo)
	})

	fi, err := os.Stat(file)
	assert.Nil(t, err)
	mtime := fi.ModTime()
	tempName := fi.Name() + ".stored"
	os.Rename(fi.Name(), tempName)

	urls := proxiesURLs
	go cfg.poll(&userConfig{}, proxyChan, urls, 1*time.Hour)
	proxies := (<-proxyChan).(map[string]*client.ChainedServerInfo)

	assert.True(t, len(proxies) > 0)
	for _, val := range proxies {
		assert.True(t, val != nil)
		assert.True(t, len(val.Addr) > 6)
	}

	for i := 1; i <= 400; i++ {
		fi, err = os.Stat(file)
		if err == nil && fi != nil && fi.ModTime().After(mtime) {
			log.Debugf("Got newer mod time?")
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	fi, err = os.Stat(file)
	if err != nil {
		log.Debugf("Got error: %v", err)
	}

	assert.NotNil(t, fi)
	assert.Nil(t, err)

	assert.True(t, fi.ModTime().After(mtime))

	// Just restore the original file.
	os.Rename(tempName, fi.Name())
}

func TestPollGlobal(t *testing.T) {
	fronted.ConfigureForTest(t)
	configChan := make(chan interface{})
	file := "./fetched-global.yaml"
	cfg := newConfig(file, false, func() interface{} {
		return &Global{}
	})

	fi, err := os.Stat(file)
	assert.Nil(t, err)
	mtime := fi.ModTime()
	tempName := fi.Name() + ".stored"
	os.Rename(fi.Name(), tempName)

	go cfg.poll(&userConfig{}, configChan, globalURLs, 1*time.Hour)

	var fetched *Global
	select {
	case fetchedConfig := <-configChan:
		fetched = fetchedConfig.(*Global)
		log.Debug("Got config from chan")
	case <-time.After(20 * time.Second):
		break
	}

	assert.False(t, &fetched == nil)

	assert.True(t, len(fetched.Client.MasqueradeSets) > 1)

	for i := 1; i <= 400; i++ {
		fi, err = os.Stat(file)
		if err == nil && fi != nil && fi.ModTime().After(mtime) {
			log.Debugf("Got newer mod time?")
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	fi, err = os.Stat(file)
	if err != nil {
		log.Debugf("Got error: %v", err)
	}
	assert.Nil(t, err)
	assert.NotNil(t, fi)
	assert.True(t, fi.ModTime().After(mtime), "Incorrect modification times")

	// Just restore the original file.
	os.Rename(tempName, fi.Name())
}
