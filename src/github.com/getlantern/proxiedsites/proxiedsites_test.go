package proxiedsites

import (
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/testify/assert"
	"testing"
	"time"
)

var mockProxiedSites = []struct {
	entry *ProxiedSites
}{
	{
		entry: New(&Config{
			Cloud:     []string{"golang.org", "swift.com", "twitter.com"},
			Additions: []string{},
			Deletions: []string{},
		}),
	},
	{
		entry: New(&Config{
			Cloud:     []string{"golang.org", "swift.com", "twitter.com"},
			Additions: []string{"cook.ie", "rand.om"},
			Deletions: []string{"twitter.com"},
		}),
	},
	{
		entry: New(&Config{
			Cloud:     []string{"golang.org", "swift.com", "twitter.com"},
			Additions: []string{"nytimes.com"},
			Deletions: []string{"twitter.com", "swift.com", "golang.org", "anoth.er"},
		}),
	},
}

func testConfig(entries []string) *Config {
	return &Config{
		Additions: []string{},
		Deletions: []string{},
		Cloud:     entries,
	}
}

func TestDiffOne(t *testing.T) {
	proxiedSites := mockProxiedSites[0].entry
	newProxiedSites := mockProxiedSites[1].entry
	cfg := proxiedSites.Diff(newProxiedSites)
	assert.Equal(t, 1, len(cfg.Deletions), "Deletions weren't the same size")
	assert.Equal(t, 2, len(cfg.Additions), "Additions weren't the same size")
}

func TestDiffTwo(t *testing.T) {
	proxiedSites := mockProxiedSites[1].entry
	newProxiedSites := mockProxiedSites[2].entry
	cfg := newProxiedSites.Diff(proxiedSites)
	assert.Equal(t, 0, len(cfg.Deletions), "Deletions weren't the same size")
	assert.Equal(t, 2, len(cfg.Additions), "Additions weren't the same size")
}

func TestPacFileUpdated(t *testing.T) {

	for _, mock := range mockProxiedSites {
		mockWl := mock.entry
		exists, _ := util.FileExists("proxy_on.pac")
		assert.Equal(t, exists, true, "proxy pac file could not be created")
		time.Sleep(1000 * time.Millisecond)
		wl := ParsePacFile()
		assert.Equal(t, wl.GetEntries, mockWl.GetEntries, "Domains weren't equal!")
	}
}
