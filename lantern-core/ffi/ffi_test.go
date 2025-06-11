package main

import (
	"log/slog"
	"os"
	"testing"

	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func radianceOptions() radiance.Options {
	return radiance.Options{
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
		DeviceID: "test-123",
		Locale:   "en-us",
	}
}

func TestCreateNewServer(t *testing.T) {
	r, err := radiance.NewRadiance(radianceOptions())
	if err != nil {
		slog.Error("Unable to create Radiance", "error", err)
	}
	assert.Nil(t, err)
	assert.NotNil(t, r)
}
