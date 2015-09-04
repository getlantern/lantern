package config

import (
	"io/ioutil"
	"testing"

	"github.com/stretchr/testify/assert"
)

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

func TestMajorVersion(t *testing.T) {
	ver := "222.0.1"
	maj := majorVersion(ver)
	assert.Equal(t, "222", maj, "Unexpected major version")
}

func TestDataCenter(t *testing.T) {
	dc := defaultRoundRobinForTerritory("IR")
	assert.Equal(t, "nl.fallbacks.getiantem.org", dc, "Unexpected data center")
	dc = defaultRoundRobinForTerritory("cn")
	assert.Equal(t, "jp.fallbacks.getiantem.org", dc, "Unexpected data center")
	dc = defaultRoundRobin()
	assert.Equal(t, "nl.fallbacks.getiantem.org", dc, "Unexpected data center")
}
