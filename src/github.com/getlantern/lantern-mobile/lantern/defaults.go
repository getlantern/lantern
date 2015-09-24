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
	"fallback-104.236.158.87": &client.ChainedServerInfo{
		Addr:        "104.236.158.87:443",
		Pipelined:   true,
		Cert:        "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIEJ40WbDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzETMBEGA1UE\nCBMKQ2FsaWZvcm5pYTEMMAoGA1UEBxMDQmluMRgwFgYDVQQKEw9Qb2lzaW5nIFBhcmNoZWQxHTAb\nBgNVBAMTFFNlYWNvYXN0cyBGdXJ0d25nbGVyMB4XDTE1MDUxMjE2NTgwM1oXDTE3MDUxMTE2NTgw\nM1owaTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExDDAKBgNVBAcTA0JpbjEYMBYG\nA1UEChMPUG9pc2luZyBQYXJjaGVkMR0wGwYDVQQDExRTZWFjb2FzdHMgRnVydHduZ2xlcjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMZKj5BYUuFnvxc2xujbLuWbaGOlnVotqfEFmMsm\nmDoiapPQsDPxfmlDQhZBfexZia5CKROko3TDEcSgBuf20+gC3rQzxX820L6bnUUDfbM4P6x0umvw\nTD0s28/jJYXQjKU2AdCGNYt9GdrhX2XZs/DPCdQaWWzR4NJU+c5cRE6fvQlAdf+Xh9q2q+4HdypX\na7a9ihQU2FlmUd1VuRLxz4Ja6mdrQ1hZoIwq7RFMnGMZgTT9B6s4SI88wMGFM6mw8Bd4joXqjdaO\nR+PTBDdw6MNh+fh5ytpMQ2bowYwYrI7xnirjScscWEWG06UwF48BSKGL0fgQCDHHfAvmoBin3NsC\nAwEAAaMyMDAwDwYDVR0RBAgwBocEaOyeVzAdBgNVHQ4EFgQUImZtoDIQfR5W8iBZqQJAuhT6KyQw\nDQYJKoZIhvcNAQELBQADggEBAK7znZLDfznwYAgs73BlFnW2nHGv5YwAXTA0eyjU6UVVMXRusEZk\n/EEuTT6LJVuycIRxylYqBB27XkevmKuGCA5aZsWhScRhMbF51z1F9BQUbpKqzzTjY359fkgAG53E\nzQK0U50CbuGQTf+y9Mb8R5VXZNZc79pRGN9eLUVn7YrsB8DqlaAeSJvojb8bc+qXbJKwQJoQ88ge\nvRa2semZ3i7A/MHRHaykV4Wq1ZWqXqjWBTbppzbZqyLNFxh5rXabCosKVJLQm4OJcmRnYorQMzZp\n7FBgavbq8Z/rXQPwalHJgcIFAdtOeB60AgAUFYQvkQ0BWrt4G5j8E8O8yUXEYDM=\n-----END CERTIFICATE-----\n",
		Weight:      1000000,
		Trusted:     true,
		UdpgwServer: "104.236.158.87:7300",
		AuthToken:   "test123",
	},
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
