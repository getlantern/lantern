package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNotPersistVersion(t *testing.T) {
	path = "./test.yaml"
	version := "version-not-on-disk"
	revisionDate := "1970-1-1"
	buildDate := "1970-1-1"
	LoadSettings(version, revisionDate, buildDate)
	assert.Equal(t, settings.Version, version, "Should be set to version")
}
