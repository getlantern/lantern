package mobile

import (
	"testing"

	"github.com/getlantern/lantern-outline/lantern-core/stub"
	"github.com/getlantern/radiance"
	"github.com/stretchr/testify/assert"
)

func TestSetupRadiance(t *testing.T) {
	rr, err := radiance.NewRadiance(stub.NewPlatformInterfaceStub())
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	err1 := rr.StartVPN()
	assert.Nil(t, err1)
}
