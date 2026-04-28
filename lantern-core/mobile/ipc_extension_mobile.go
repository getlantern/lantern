//go:build android || ios || darwin

package mobile

import (
	"github.com/getlantern/radiance/backend"
	"github.com/getlantern/radiance/ipc"
)

func newLoopbackClient(be *backend.LocalBackend) *ipc.Client {
	return ipc.NewLoopbackClient(be)
}
