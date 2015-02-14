package proxiedsites

import (
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/testify/assert"
	"testing"
	"time"
)

var (
	pacFilePath = PacFilename
)

var mockWhitelists = []struct {
	entry *Whitelist
}{
	{
		entry: New(&Config{
			Cloud:     []string{},
			Additions: []string{},
			Deletions: []string{},
		}),
	},
	{
		entry: New(&Config{
			Cloud:     []string{"golang.org", "swift.com", "twitter.com"},
			Additions: []string{},
			Deletions: []string{},
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

func TestPacFileUpdated(t *testing.T) {
	PacFilePath = "proxy_on.pac"
	PacTmpl = "templates/proxy_on.pac.template"

	for _, mock := range mockWhitelists {
		mockWl := mock.entry
		exists, _ := util.FileExists("proxy_on.pac")
		assert.Equal(t, exists, true, "proxy pac file could not be created")
		mockWl.RefreshEntries()
		time.Sleep(1000 * time.Millisecond)
		wl := ParsePacFile()
		assert.Equal(t, wl.GetEntries(), mockWl.GetEntries(), "Test domains are not equal!")

	}
}
