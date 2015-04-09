package detour

import (
	"testing"

	"github.com/getlantern/testify/assert"
)

var ()

func TestCheckSubdomain(t *testing.T) {
	wl := []string{
		"facebook.com:80",
	}
	InitWhitelist(wl)
	assert.True(t, whitelisted("www.facebook.com:80"), "should match subdomain")
}

func TestDumpWhiteList(t *testing.T) {
	addToWl("a.com:80", true)
	addToWl("b.com:80", false)
	dumped := DumpWhitelist()
	assert.Contains(t, dumped, "a.com:80", "dumped list should contain permanent items")
	assert.NotContains(t, dumped, "b.com:80", "dumped list should not contain temporary items")
}
