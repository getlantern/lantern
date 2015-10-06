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
		UdpgwServer: true,
		AuthToken:   "test123",
	},
	"fallback-178.62.252.86": &client.ChainedServerInfo{
		Addr:      "45.32.15.9:443",
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIFdjCCA16gAwIBAgIEKMaDwjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEVMBMGA1UE\nCBMMTWFzc2FjaHVzZXRzMQ8wDQYDVQQHEwZCZWhhdmUxDjAMBgNVBAoTBUxvcnJ5MRwwGgYDVQQD\nExNJbnRlbnRpb24gSHlwb2NyaXRlMB4XDTE1MDYyODEzMDE0NVoXDTE2MDYyNzEzMDE0NVowYzEL\nMAkGA1UEBhMCVVMxFTATBgNVBAgTDE1hc3NhY2h1c2V0czEPMA0GA1UEBxMGQmVoYXZlMQ4wDAYD\nVQQKEwVMb3JyeTEcMBoGA1UEAxMTSW50ZW50aW9uIEh5cG9jcml0ZTCCAiIwDQYJKoZIhvcNAQEB\nBQADggIPADCCAgoCggIBAISgouoNwv4gk/MEuz0mC7wYydib5+HFifz//qazsS//Mxxl9uX83ylP\nycTCtdeGFCtSzukrexziWVITPHwg9DEaKDA3BEXSKG8MKiqO1iyWCm5TmOXEe3zvuOAV61NOrIjW\nxWPu7U1kESSDf0NdjBm13pgdFgo6rbFKS/1tTRUfA3jv5vPZaxy53ZGwpiCUbNdSZ2IbOQ/OQ35d\n6uysgy24fuOdfinZArZMS3RwSIB/oSswYcjfe4I+d/FzsvmYS9Fu54iUsfhQvKHA3uIB2muxRi2Z\nNFxUhLw3Aj2CUKeeIqtp/+RrE4u926T3rr3UoGKSQ128B5w0nB30TApNgkwsw593MHlpKE/zo3z/\ni2KLm2ByxC3VOzfS1w+tDgE1h+O9aB6Usc7UbNExR0M1XXB1z1uIV/e2XaBsNcBo7aNRBtgEjRQS\nn3hg6Vip+i0l6XyraXXXAk2m5erSuvdN18ApHJ4qkBQk0ZgCB/W3rmW86dTdXAyVCB5uAx31MsM3\nilKfGAdf0HIJVsNNKB5cVWp5azR3GBVb0pXhUyXjBpNlptjuzVLuJxcTLactFpmVKnQJmsAfxlWx\neYigWlMJeqn4FHpVI6GYNPRe8Ev5MvNnfXBQ6Fy7FCxCc6QltAHQAhs9B9ZEOotn8osejTPFjmRb\n0RmQeW6Zs9riIMtlJqcjAgMBAAGjMjAwMA8GA1UdEQQIMAaHBC0gDwkwHQYDVR0OBBYEFITVc23L\nNINV822jxjfVp/0VFP3cMA0GCSqGSIb3DQEBCwUAA4ICAQB+1jGSoZBY5FrDxcuBMs3mQl79AXG1\ngAIA5+QWr9MLbEOp5SO0LqD/qI42TXnjILg1ox3yrrZJxM0sJOlPPUC9jABz9LB3tUA1Puci7yoj\nYnnvwgM/jtlVlOnJy6tfY2HRE83jfcXl5NSfR9Rf+/ZE1CyUgQWGggff1rpZZgOOMM6ftAFbNlgu\n7BTJu21jPINbTDN7RLL8DvMySu7cfBJl1yizKaDNo4W+WzymK61sg8MFDjpzvPb1ka+iG1lM/7f5\nTFgdtx1BH3GVle4Ht+SN8ccJqFBEQ8dB/w3xI2+IEAZi/ixoA+bJkzJ5vRg3BUF2K+4g/hlvt1vv\nSAPZIF8RjQfeL/4Zw2honYSqC4T2SCR5rP+QCVZgGuh0bw5oSsdkXhTLXj032xZwQUO/Yj5ZfJLS\nx97MHrZwBDSzUNtdEdNZxYhgTT/USEC4wgUltE5nZVWlXsOMvGjxRjeJ2HMUFynaXWWbXhNk7hvy\nE538Qw+jfHJzKqWeTeiYiUbjJd086DMMAxxkMLGnz1gkNjZCPaCUTwxkQDM7Za7IMZ9Uwl9KIsfZ\nrifCjzuZdXSHnTRbeSMeU7PE3AN+VYFhnVY2kLGkxHtl541MbrlUZhkXwtAtaXxLlQXpEdKxzdb4\nA33lWy+1zgkWrU0Aqy9Mm+VBtvkoBq1dKlCI/Jz1BIYkdA==\n-----END CERTIFICATE-----",
		AuthToken: "sAcRACKt5CyamoBm2PUBaciKKZm0GO86HnxM65ZshjfgUwXaWnYtx0VyH3JqZkuc",
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
