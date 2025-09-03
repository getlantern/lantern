package vpn_tunnel

import (
	"context"

	"github.com/sagernet/sing-box/experimental/clashapi"
)

var (
	clashSrv *clashapi.Server
	srvCtx   context.Context
)

func SetRuntime(ctx context.Context, srv *clashapi.Server) {
	srvCtx = ctx
	clashSrv = srv
}

func ClashServer() *clashapi.Server { return clashSrv }
func Ctx() context.Context          { return srvCtx }
