//go:build !android && !ios && !darwin

package mobile

import (
	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/ipc"
)

func newLoopbackClient(_ *backend.LocalBackend) *ipc.Client {
	return nil
}
