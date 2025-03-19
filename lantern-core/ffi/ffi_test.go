package main

import (
	"testing"

	"github.com/getlantern/golog"
	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func TestCreateNewServer(t *testing.T) {
	log := golog.LoggerFor("lantern.vpn")
	r, err := radiance.NewRadiance(nil)
	if err != nil {
		log.Errorf("Unable to create Radiance: %v", err)

	}
	assert.NotNil(t, r)
	log.Debug("Radiance setup successfully")
}
