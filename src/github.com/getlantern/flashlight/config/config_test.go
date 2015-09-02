package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMajorVersion(t *testing.T) {
	ver := majorVersion("22.0.2")

	assert.Equal(t, "22", ver, "Could not read version")
}
