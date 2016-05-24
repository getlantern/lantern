package config

import (
	"io/ioutil"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestStagingSetup tests to make sure our staging config flag sets the
// appropriate URLs for staging servers.
func TestInit(t *testing.T) {
	configDir, errr := ioutil.TempDir("", "config-testing")
	if errr != nil {
		log.Fatal(errr)
	}

	defer os.RemoveAll(configDir)

	userConfig := &userConfig{}
	version := "test-version"
	flagsAsMap := make(map[string]interface{})
	flagsAsMap["staging"] = false

	stickyConfig := false
	var cfg *Config
	var err error
	cfg, err = Init(userConfig, version, configDir, stickyConfig, flagsAsMap)
	assert.Nil(t, err)

	assert.Equal(t, configDir, cfg.configDir)
	assert.Equal(t, "", cfg.CloudConfigCA)
}

func TestMajorVersion(t *testing.T) {
	ver := "222.00.1"
	maj := majorVersion(ver)
	assert.Equal(t, "222.00", maj, "Unexpected major version")
}
