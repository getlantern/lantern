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
		Addr:      "104.236.158.87:443",
		Pipelined: true,
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIEJ40WbDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQGEwJVUzETMBEGA1UE\nCBMKQ2FsaWZvcm5pYTEMMAoGA1UEBxMDQmluMRgwFgYDVQQKEw9Qb2lzaW5nIFBhcmNoZWQxHTAb\nBgNVBAMTFFNlYWNvYXN0cyBGdXJ0d25nbGVyMB4XDTE1MDUxMjE2NTgwM1oXDTE3MDUxMTE2NTgw\nM1owaTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExDDAKBgNVBAcTA0JpbjEYMBYG\nA1UEChMPUG9pc2luZyBQYXJjaGVkMR0wGwYDVQQDExRTZWFjb2FzdHMgRnVydHduZ2xlcjCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMZKj5BYUuFnvxc2xujbLuWbaGOlnVotqfEFmMsm\nmDoiapPQsDPxfmlDQhZBfexZia5CKROko3TDEcSgBuf20+gC3rQzxX820L6bnUUDfbM4P6x0umvw\nTD0s28/jJYXQjKU2AdCGNYt9GdrhX2XZs/DPCdQaWWzR4NJU+c5cRE6fvQlAdf+Xh9q2q+4HdypX\na7a9ihQU2FlmUd1VuRLxz4Ja6mdrQ1hZoIwq7RFMnGMZgTT9B6s4SI88wMGFM6mw8Bd4joXqjdaO\nR+PTBDdw6MNh+fh5ytpMQ2bowYwYrI7xnirjScscWEWG06UwF48BSKGL0fgQCDHHfAvmoBin3NsC\nAwEAAaMyMDAwDwYDVR0RBAgwBocEaOyeVzAdBgNVHQ4EFgQUImZtoDIQfR5W8iBZqQJAuhT6KyQw\nDQYJKoZIhvcNAQELBQADggEBAK7znZLDfznwYAgs73BlFnW2nHGv5YwAXTA0eyjU6UVVMXRusEZk\n/EEuTT6LJVuycIRxylYqBB27XkevmKuGCA5aZsWhScRhMbF51z1F9BQUbpKqzzTjY359fkgAG53E\nzQK0U50CbuGQTf+y9Mb8R5VXZNZc79pRGN9eLUVn7YrsB8DqlaAeSJvojb8bc+qXbJKwQJoQ88ge\nvRa2semZ3i7A/MHRHaykV4Wq1ZWqXqjWBTbppzbZqyLNFxh5rXabCosKVJLQm4OJcmRnYorQMzZp\n7FBgavbq8Z/rXQPwalHJgcIFAdtOeB60AgAUFYQvkQ0BWrt4G5j8E8O8yUXEYDM=\n-----END CERTIFICATE-----\n",
		Weight:    1000000,
		Trusted:   true,
		AuthToken: "test123",
	},
}

// defaultMasqueradeSets holds the default masquerades for fronted servers.
var defaultMasqueradeSets = map[string][]*fronted.Masquerade{
	// See masquerades.go
	cloudflare: cloudflareMasquerades,
}
