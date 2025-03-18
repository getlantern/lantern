package main

import (
	"testing"

	"github.com/getlantern/golog"
	"github.com/getlantern/lantern-outline/lantern-core/empty"
	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func TestCreateNewServer(t *testing.T) {
	log := golog.LoggerFor("lantern.vpn")
	platform := empty.EmptyPlatform{}
	log.Debug("empty platform created")
	r, err := radiance.NewRadiance(platform)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)

	}
	assert.NotNil(t, r)
	log.Debug("Radiance setup successfully")
}
