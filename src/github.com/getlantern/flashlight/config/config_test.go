package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

/*
func TestInitialConfig(t *testing.T) {
	path, _ := ioutil.TempFile("", "config")

	yamlPath := "test-packaged.yaml"
	data, err := ioutil.ReadFile(yamlPath)
	if err != nil {
		// This will happen whenever there's no packaged settings, which is often
		log.Debugf("Error reading file %v", err)
	}

	trimmed := strings.TrimSpace(string(data))

	log.Debugf("Read bytes: %v", trimmed)
	var s client.BootstrapSettings
	err = yaml.Unmarshal([]byte(trimmed), &s)

	if err != nil {
		log.Errorf("Could not read yaml: %v", err)
	}
	err = fetchInitialConfig(path.Name(), &s)
	assert.Nil(t, err, "Should not get an error fetching config")
}
*/
/*
func TestCopyOldConfig(t *testing.T) {
	existsFunc := func(file string) (string, bool) {
		return "fullpath", true
	}

	path := copyNewest("lantern-2.yaml", existsFunc)
	assert.Equal(t, "fullpath", path, "unexpected path used")

	// Test with temp files to make sure the actual copy of an old file to a
	// new one works.
	tf, _ := ioutil.TempFile("", "2.0.1")
	tf2, _ := ioutil.TempFile("", "2.0.2")

	log.Debugf("Created temp file: %v", tf.Name())

	existsFunc = func(file string) (string, bool) {
		if file == "lantern-2.0.1.yaml" {
			return tf.Name(), true
		}
		return tf2.Name(), false
	}

	path = copyNewest("lantern-2.yaml", existsFunc)
	assert.Equal(t, tf.Name(), path, "unexpected path used")
}
*/

func TestMajorVersion(t *testing.T) {
	ver := "222.00.1"
	maj := majorVersion(ver)
	assert.Equal(t, "222.00", maj, "Unexpected major version")
}
