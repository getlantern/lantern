package settings

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestSettings(t *testing.T) {
	version := "test"
	revisionDate := "test"
	buildDate := "test"
	Load(version, revisionDate, buildDate)

	assert.Equal(t, settings.AutoLaunch, true, "Should be set to auto launch")

	// Reset the variables for loading the yaml.
	path = "./test.yaml"

	Load(version, revisionDate, buildDate)

	assert.Equal(t, settings.AutoLaunch, false, "Should not be set to auto launch")
}

func TestNotPersistVersion(t *testing.T) {
	version := "old-version"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	Load(version, revisionDate, buildDate)
	assert.Equal(t, settings.Version, "old-version", "Should be set to version")

	path = "./test.yaml"
	version = "new-version"

	Load(version, revisionDate, buildDate)
	assert.Equal(t, settings.Version, "new-version", "Should be set to a new version")
}
