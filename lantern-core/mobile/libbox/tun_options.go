package libbox

import (
	"net"
	"net/netip"

	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common"
	E "github.com/sagernet/sing/common/exceptions"
)

type Options interface {
	GetInet4Address() RoutePrefixIterator
	GetInet6Address() RoutePrefixIterator
	GetDNSServerAddress() (*StringBox, error)
	GetMTU() int32
	GetAutoRoute() bool
	GetStrictRoute() bool
	GetInet4RouteAddress() RoutePrefixIterator
	GetInet6RouteAddress() RoutePrefixIterator
	GetInet4RouteExcludeAddress() RoutePrefixIterator
	GetInet6RouteExcludeAddress() RoutePrefixIterator
	GetInet4RouteRange() RoutePrefixIterator
	GetInet6RouteRange() RoutePrefixIterator
	GetIncludePackage() StringIterator
	GetExcludePackage() StringIterator
	IsHTTPProxyEnabled() bool
	GetHTTPProxyServer() string
	GetHTTPProxyServerPort() int32
	GetHTTPProxyBypassDomain() StringIterator
	GetHTTPProxyMatchDomain() StringIterator
}

type RoutePrefix struct {
	address netip.Addr
	prefix  int
}

func (p *RoutePrefix) Address() string {
	return p.address.String()
}

func (p *RoutePrefix) Prefix() int32 {
	return int32(p.prefix)
}

func (p *RoutePrefix) Mask() string {
	var bits int
	if p.address.Is6() {
		bits = 128
	} else {
		bits = 32
	}
	return net.IP(net.CIDRMask(p.prefix, bits)).String()
}

func (p *RoutePrefix) String() string {
	return netip.PrefixFrom(p.address, p.prefix).String()
}

type RoutePrefixIterator interface {
	Next() *RoutePrefix
	HasNext() bool
}

func mapRoutePrefix(prefixes []netip.Prefix) RoutePrefixIterator {
	return newIterator(common.Map(prefixes, func(prefix netip.Prefix) *RoutePrefix {
		return &RoutePrefix{
			address: prefix.Addr(),
			prefix:  prefix.Bits(),
		}
	}))
}

var _ Options = (*TunOptions)(nil)

type TunOptions struct {
	*tun.Options
	routeRanges []netip.Prefix
	option.TunPlatformOptions
}

func (o *TunOptions) GetInet4Address() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet4Address)
}

func (o *TunOptions) GetInet6Address() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet6Address)
}

func (o *TunOptions) GetDNSServerAddress() (*StringBox, error) {
	if len(o.Inet4Address) == 0 || o.Inet4Address[0].Bits() == 32 {
		return nil, E.New("need one more IPv4 address for DNS hijacking")
	}
	return wrapString(o.Inet4Address[0].Addr().Next().String()), nil
}

func (o *TunOptions) GetMTU() int32 {
	return int32(o.MTU)
}

func (o *TunOptions) GetAutoRoute() bool {
	return o.AutoRoute
}

func (o *TunOptions) GetStrictRoute() bool {
	return o.StrictRoute
}

func (o *TunOptions) GetInet4RouteAddress() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet4RouteAddress)
}

func (o *TunOptions) GetInet6RouteAddress() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet6RouteAddress)
}

func (o *TunOptions) GetInet4RouteExcludeAddress() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet4RouteExcludeAddress)
}

func (o *TunOptions) GetInet6RouteExcludeAddress() RoutePrefixIterator {
	return mapRoutePrefix(o.Inet6RouteExcludeAddress)
}

func (o *TunOptions) GetInet4RouteRange() RoutePrefixIterator {
	return mapRoutePrefix(common.Filter(o.routeRanges, func(it netip.Prefix) bool {
		return it.Addr().Is4()
	}))
}

func (o *TunOptions) GetInet6RouteRange() RoutePrefixIterator {
	return mapRoutePrefix(common.Filter(o.routeRanges, func(it netip.Prefix) bool {
		return it.Addr().Is6()
	}))
}

func (o *TunOptions) GetIncludePackage() StringIterator {
	return newIterator(o.IncludePackage)
}

func (o *TunOptions) GetExcludePackage() StringIterator {
	return newIterator(o.ExcludePackage)
}

func (o *TunOptions) IsHTTPProxyEnabled() bool {
	if o.TunPlatformOptions.HTTPProxy == nil {
		return false
	}
	return o.TunPlatformOptions.HTTPProxy.Enabled
}

func (o *TunOptions) GetHTTPProxyServer() string {
	return o.TunPlatformOptions.HTTPProxy.Server
}

func (o *TunOptions) GetHTTPProxyServerPort() int32 {
	return int32(o.TunPlatformOptions.HTTPProxy.ServerPort)
}

func (o *TunOptions) GetHTTPProxyBypassDomain() StringIterator {
	return newIterator(o.TunPlatformOptions.HTTPProxy.BypassDomain)
}

func (o *TunOptions) GetHTTPProxyMatchDomain() StringIterator {
	return newIterator(o.TunPlatformOptions.HTTPProxy.MatchDomain)
}
