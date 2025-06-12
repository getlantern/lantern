package privateserver

import (
	"context"

	"github.com/getlantern/lantern-server-provisioner/common"
	"github.com/getlantern/lantern-server-provisioner/digitalocean"
)

func AddDigitalOceanServerRoutes(ctx context.Context, browserStart common.BrowserOpener) common.Provisioner {
	provisioner := digitalocean.GetProvisioner(ctx, browserStart)
	return provisioner
}
