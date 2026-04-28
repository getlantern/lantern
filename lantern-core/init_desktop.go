//go:build !android && !ios && !darwin

package lanterncore

import (
	"context"

	"github.com/getlantern/radiance/ipc"

	"github.com/getlantern/lantern/lantern-core/utils"
)

func createClient(_ context.Context, _ *utils.Opts) (*ipc.Client, error) {
	return ipc.NewClient(), nil
}
