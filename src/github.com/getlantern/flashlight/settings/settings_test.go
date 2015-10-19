package settings

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestBootstrapSettings(t *testing.T) {
	version := "test"
	revisionDate := "test"
	buildDate := "test"
	Load(version, revisionDate, buildDate)

	assert.Equal(t, settings.AutoLaunch, true, "Should be set to auto launch")

	// Reset the variables for loading the yaml.
	name = "test.yaml"
	dir = "."
	//path := filepath.Join(dir, "test.yaml")

	Load(version, revisionDate, buildDate)

	assert.Equal(t, settings.AutoLaunch, false, "Should not be set to auto launch")
	/*
		set := &Settings{
			Version:      version,
			BuildDate:    buildDate,
			RevisionDate: revisionDate,
			AutoReport:   true,
			AutoLaunch:   true,
			ProxyAll:     false,
		}
		if bytes, err := yaml.Marshal(set); err != nil {
			t.Fail()
		} else if err := ioutil.WriteFile(path, bytes, 0644); err != nil {
			t.Fail()
		}
	*/
}
