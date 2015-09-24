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
	"fallback-178.62.252.86": &client.ChainedServerInfo{
		Addr:      "178.62.252.86:443",
		Pipelined: true,
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIDjDCCAnSgAwIBAgIEMWlPLzANBgkqhkiG9w0BAQsFADBuMQswCQYDVQQGEwJVUzERMA8GA1UE\nCBMITmV3IFlvcmsxFTATBgNVBAcTDE1lbW9yaXphdGlvbjE1MDMGA1UEAxMsT3ZlcmxheSBXb3Js\nZGxpbmVzcyBSZXRvb2xpbmcgRGlzZXN0YWJsaXNoZWQwHhcNMTQxMjE2MDMyMjA2WhcNMTUxMjE2\nMDMyMjA2WjBuMQswCQYDVQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxFTATBgNVBAcTDE1lbW9y\naXphdGlvbjE1MDMGA1UEAxMsT3ZlcmxheSBXb3JsZGxpbmVzcyBSZXRvb2xpbmcgRGlzZXN0YWJs\naXNoZWQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCInqcm0pZtM/6WalIuNwnY/qVq\n9ClKH1ZBdKV4rxArE4VHYD0FdqefUAM9ip+ugNAkEIZuu5yMAwSu7Dr/3eMajIAOgEWlqaV2gzlr\nIExY2sQ6r6WQcZs1K6tVXNU0IZczq1ozdTfenM8cSX0K1aTM+vP+kWFfy4KGbr6n31jFTZjIdqPE\nOw3SS9KsWb5QnNZjqmF1uQHuwNgxxRm9QQHLKh5wicESvdgKBiY7PtuJGN8rmsg0W4RLMCc9mR2Q\n3naiAmRMi328Lh9jOA0/YyVNdVrlUPFinK/f3p+kuP7rZ27Or9cuDQIcp4iyf0Gx5WkPNGMvTecP\nMi92/aBDN851AgMBAAGjMjAwMA8GA1UdEQQIMAaHBLI+/FYwHQYDVR0OBBYEFHf70Y0mBQR9OT8a\nS1PUJjoZTJ2DMA0GCSqGSIb3DQEBCwUAA4IBAQBMvvQgPN7vdqldSZG0QfrU4KxIIUWlwVf6TPfZ\nLwpnMByKqzx1rzAva/NpNvNNSsOLCgD4VXfSUIwULfAtqst7ZGlw+VkdcTLeTU/8sug/4JOFD803\nO83a4rRbXesB5ofH0q1zcpJNVpWlqNDY2f4A5ExWC1uCscbH2x/kIutC9PSThc4uwIhOs4SyUzGz\nnoz9V2wFUzfgxJz71e/z2G3h2orb2RHcBAeSKNODULSbXMf2cHPiRvFZmf9v3a6dhb5h5Zrks+8P\nVSLsRWWQpSnCqR6NOQsbFadw/eu4hhkDq1wKbTodSAZBLDxitvCxUAK7+1cEfFQwgaY/eWt244tj\n-----END CERTIFICATE-----\n",
		AuthToken: "ZgYvLil6Hohj8RfIE0kT1BP5ZFtIVnik5T76nQt6yjjmZ9gEh5Vj2QKUStQ69V1a",
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
