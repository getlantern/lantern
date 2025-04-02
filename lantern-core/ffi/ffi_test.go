package main

import (
	"log/slog"
	"testing"

	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func TestCreateNewServer(t *testing.T) {
	r, err := radiance.NewRadiance("", nil)
	if err != nil {
		slog.Error("Unable to create Radiance", "error", err)

	}
	assert.NotNil(t, r)
	slog.Debug("Radiance setup successfully")
}
