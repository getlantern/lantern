package wintunmgr

import (
	"context"

	"github.com/getlantern/lantern-outline/lantern-core/vpn_tunnel"
	"github.com/getlantern/radiance/vpn/ipc"
	"github.com/sagernet/sing-box/experimental/clashapi"
)

type ipcAdapter struct{ s *Service }

func (a *ipcAdapter) Ctx() context.Context { return vpn_tunnel.Ctx() }
func (a *ipcAdapter) Status() string {
	if a.s.isRunning() {
		return ipc.StatusRunning
	}
	return ipc.StatusClosed
}
func (a *ipcAdapter) ClashServer() *clashapi.Server { return vpn_tunnel.ClashServer() }
func (a *ipcAdapter) Close() error                  { return vpn_tunnel.StopVPN() }
