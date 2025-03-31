package libbox

import (
	"context"
	"net/netip"
	"strings"
	"syscall"

	"github.com/sagernet/sing/common"
	E "github.com/sagernet/sing/common/exceptions"
	M "github.com/sagernet/sing/common/metadata"

	mDNS "github.com/miekg/dns"
)

type LocalDNSTransport interface {
	Raw() bool
	Lookup(ctx *ExchangeContext, network string, domain string) error
	Exchange(ctx *ExchangeContext, message []byte) error
}

type Func interface {
	Invoke() error
}

type ExchangeContext struct {
	context   context.Context
	message   mDNS.Msg
	addresses []netip.Addr
	error     error
}

func (c *ExchangeContext) OnCancel(callback Func) {
	go func() {
		<-c.context.Done()
		callback.Invoke()
	}()
}

func (c *ExchangeContext) Success(result string) {
	c.addresses = common.Map(common.Filter(strings.Split(result, "\n"), func(it string) bool {
		return !common.IsEmpty(it)
	}), func(it string) netip.Addr {
		return M.ParseSocksaddrHostPort(it, 0).Unwrap().Addr
	})
}

func (c *ExchangeContext) RawSuccess(result []byte) {
	err := c.message.Unpack(result)
	if err != nil {
		c.error = E.Cause(err, "parse response")
	}
}

func (c *ExchangeContext) ErrorCode(code int32) {
	//c.error = dns.RcodeError(code)
}

func (c *ExchangeContext) ErrnoCode(code int32) {
	c.error = syscall.Errno(code)
}
