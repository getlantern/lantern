package client

import (
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/fronted"
)

const (
	cloudflare = `cloudflare`
)

const (
	defaultBufferRequest = false
)

// defaultFrontedServerList holds the list of fronted servers.
var defaultFrontedServerList = []*client.FrontedServerInfo{
	&client.FrontedServerInfo{
		Host:          "roundrobin.getiantem.org",
		Port:          443,
		MasqueradeSet: cloudflare,
		QOS:           10,
		Weight:        1000000,
	},
}

var defaultChainedServers = map[string]*client.ChainedServerInfo{
	"fallback-188.166.77.218:443": &client.ChainedServerInfo{
		Addr:      "188.166.77.218:443",
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIDTDCCAjSgAwIBAgIEFCFKlzANBgkqhkiG9w0BAQsFADBOMQswCQYDVQQGEwJVUzERMA8GA1UE\nCBMITmV3IFlvcmsxDzANBgNVBAcTBkFydGlzdDEbMBkGA1UEAxMSUHJlc2VudGVkIFN0YWRpdW1z\nMB4XDTE1MDYyMzE3NTkwMloXDTE2MDYyMjE3NTkwMlowTjELMAkGA1UEBhMCVVMxETAPBgNVBAgT\nCE5ldyBZb3JrMQ8wDQYDVQQHEwZBcnRpc3QxGzAZBgNVBAMTElByZXNlbnRlZCBTdGFkaXVtczCC\nASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKG96Kw5OUXfHrLOUA3QvrZ5nz06MaOgKi1+\nNLTkD0YaEVyJnV10IKb41JbP3BCNasICRbD1A3n7mph5ahhncDu0ktLKG2CI+ZLL9/mGsuJCTtaF\nF0JhxtWTVItkk+yXUJv5q/hz+GFm/IwGHHjuOlfLsERBi0+O0OmrPQ4yzIexueeUf0YqJ1H+9XVN\nbKP7roCMbAxLA6M5Jb6A7vN6tejMNpRFB1AkfZqdvMegezI8GeMEVsrWaDVdqerpIA90vMQj9Xe0\nHqC370LPFxfsYxOo5smaU23AZpihGel1VDGLC8yAuC2VYzGS5QMw4bHc/UWFScMLRHEeK3wKs4aZ\nvZ0CAwEAAaMyMDAwDwYDVR0RBAgwBocEvKZN2jAdBgNVHQ4EFgQUF0YrAIDgbjsiQHq4NWrwo3yv\nECQwDQYJKoZIhvcNAQELBQADggEBAH3LMjPNX6Ux1oaPT/KoGUFN1ZRRMLY9OvvrfYYQYI7VtzFA\nxUgJhrLC4Q4kU+ZimNXbLUlxlkuyr5xTngYco/lA98kWWcJBpsHTB9CCGPzYed+rIOL/mnsslhtn\n6Wm8oE6qab9QgJwymXIsf+nHq5lv2UAKeA1ex2/JnM+H6Gab0kAxYapnpVfApuzR4CCK22sVadQi\n86ZSBhQDE4IkRCljoGN/8jBUvhZgvK74vDwbA6zs7fpAuOyisnGEX/zaau4gEE+Tly4mV4VpWoUM\nDjK33MsAAhzjpWSGxcty7QwAjnZyZh+QaNRA0BUKem8mrDOPpXvmPSLjG3eQ4+gYncc=\n-----END CERTIFICATE-----\n",
		AuthToken: "lKrYGuFN99ptlmywrAVFbKDN6sxx1VbKXOSAYIz7pIhgfclvtOEzAg8h4zIQ8gin",
		Pipelined: true,
		Weight:    1000000,
		QOS:       10,
		Trusted:   true,
	},
}

// defaultMasqueradeSets holds the default masquerades for fronted servers.
var defaultMasqueradeSets = map[string][]*fronted.Masquerade{
	// See masquerades.go
	cloudflare: cloudflareMasquerades,
}
