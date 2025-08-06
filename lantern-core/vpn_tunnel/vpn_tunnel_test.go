package vpn_tunnel

import (
	"os"
	"testing"

	"github.com/getlantern/lantern-outline/lantern-core/stub"
	"github.com/getlantern/lantern-outline/lantern-core/utils"
	"github.com/getlantern/radiance"
	"github.com/zeebo/assert"
)

func TestStartVPN(t *testing.T) {
	radiance.NewRadiance(radianceOptions())
	pltf := stub.NewPlatformInterfaceStub()
	err := StartVPN(pltf, &utils.Opts{})
	assert.NoError(t, err)

}

func radianceOptions() radiance.Options {
	return radiance.Options{
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
		DeviceID: "test-123",
		Locale:   "en-us",
	}
}
