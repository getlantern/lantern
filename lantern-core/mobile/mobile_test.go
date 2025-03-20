package mobile

import (
	"testing"

	"github.com/getlantern/lantern-outline/lantern-core/empty"
	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func TestSetupRadiance(t *testing.T) {
	rr, err := radiance.NewRadiance(empty.NewPlatformInterfaceStub())
	assert.Nil(t, err)
	assert.NotNil(t, rr)
}
