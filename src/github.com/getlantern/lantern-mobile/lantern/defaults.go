package client

import (
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/fronted"
)

const (
	cloudfront = "cloudfront"
)

const (
	defaultBufferRequest = false
)

// defaultFrontedServerList holds the list of fronted servers.
var defaultFrontedServerList = []*client.FrontedServerInfo{}

var defaultChainedServers = map[string]*client.ChainedServerInfo{
	"fallback-178.62.253.77": &client.ChainedServerInfo{
		Addr:      "178.62.253.77:443",
		AuthToken: "9iFx9mLBBMtktvAYT9tgmbrmaclw4lK96UGj0C0ETce0ugazkZduKJ8VLJxcvILS",
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIBtDCCAVigAwIBAgIEDkatVDAMBggqhkjOPQQDAgUAMEYxCzAJBgNVBAYTAlVTMREwDwYDVQQI EwhOZXcgWW9yazESMBAGA1UEBxMJVHJhbnNtaXRzMRAwDgYDVQQDEwdCYXJ0ZXJzMB4XDTE1MTEw MzIwMTgxOFoXDTE2MTEwMjIwMTgxOFowRjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCE5ldyBZb3Jr MRIwEAYDVQQHEwlUcmFuc21pdHMxEDAOBgNVBAMTB0JhcnRlcnMwWTATBgcqhkjOPQIBBggqhkjO PQMBBwNCAAQsVlHu7pE7WcrEl/7Ss+cTRv7X0x0GPd2iIaunU0jkMoN9XM+3YiN03etrbH05Htci Zul/lpIixl0xbtGyczooozIwMDAPBgNVHREECDAGhwSyPv1NMB0GA1UdDgQWBBSPCi1Cgxeo0yVh V4UQalrDkr9iQTAMBggqhkjOPQQDAgUAA0gAMEUCIGkMsdEkwhyOXzJUljCibpElAbMme5T8Qx/m OSdklt6iAiEA+UHdwSUUvzYcpU1E9Q2eCNXxIwZwEWPdiFj7PHx9MPo=\n-----END CERTIFICATE-----\n",
		Weight:    1000000,
		Pipelined: true,
		QOS:       10,
		Trusted:   true,
	},
	"fallback-188.166.119.231": &client.ChainedServerInfo{
		Addr:      "188.166.119.231:443",
		AuthToken: "BkoSZcewV05oSDblft3tXZJoWmeY2G23wzv2VcvjS07TyB7O6ydoaKIpAmzkBS4r",
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIDhjCCAm6gAwIBAgIEeYtt3TANBgkqhkiG9w0BAQsFADBrMQswCQYDVQQGEwJVUzETMBEGA1UE CBMKQ2FsaWZvcm5pYTERMA8GA1UEBxMIQ2x1bmtpZXIxGDAWBgNVBAoTD0NvbXBldGl0b3IgTW9u azEaMBgGA1UEAxMRU3Rvcnlib29rcyBHYXJpc2gwHhcNMTUwNzE5MTMyNjI3WhcNMTYwNzE4MTMy NjI3WjBrMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTERMA8GA1UEBxMIQ2x1bmtp ZXIxGDAWBgNVBAoTD0NvbXBldGl0b3IgTW9uazEaMBgGA1UEAxMRU3Rvcnlib29rcyBHYXJpc2gw ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCOMInbD9KDIy2hb+628jGxsZhBus+zPaC1 YVeO/DIuuboSIQ/n7SthTfGlgs6G8B3kDEl0uSp9ZzqAIG6tuNVyPIrqw6eRnODEj9W8No+AXGxM DMWnuB77Di8C4Su8lCydeLC0LNc9S/y+RhLanShsczlP5fuut73CxE0+SdtCkJfHyjB2UpiKvoDT A2vTdlXf3R+9oLE7sKRZ1z6NZE2BovWWhp7cHDCTpndhFGT9T8wdgrCn7SMySNjE7BVix6u0Lta+ V5ScmUuasASk2HWgzhFw19Jvj9odp6ckuV8Y1cA5HyPkXzdpAO9CFRH7BYlqC1Aq5aIHGCzwFb1n RlAvAgMBAAGjMjAwMA8GA1UdEQQIMAaHBLymd+cwHQYDVR0OBBYEFMp7kpuHFz20691eHe/TMJ6B p3UsMA0GCSqGSIb3DQEBCwUAA4IBAQBZtSwgOgE0rc1nlU+22Drgv54hWBtYQZmT4851OTrEE9O8 CeKD6VZ0Hz1wtEcrJdFEAK23kqzHnGHM5KyS56tB1UACYQeojB4fnDobDt+vddHmL9xPvWWUan42 TByWUh4E/mnMw7VT4qVMFyVT9TuKlPkRrR4UG+yDw0UMm44iK2kFmBb+aJEWbxs3/tnpTXcnF3qY aL6P0TkP/rA+TihlS3FP+DcBK6+aJOPpWnIReIFHfoKptQTIp4j++mawWhpdnVAMk1m3a3te/yQ0 ooME4kyf0qRlNCRbHAS4H4Wek/obrbn614Eo9kafMoPwhFQxTNxzsPFFbn1MMGKG5yMR\n-----END CERTIFICATE-----\n",
		Weight:    1000000,
		Pipelined: true,
		QOS:       10,
		Trusted:   true,
	},
	"fallback-188.166.64.159": &client.ChainedServerInfo{
		Addr:      "188.166.64.159:443",
		AuthToken: "7zCeBYQAz653GYtjuEso0hihHfm5QIeK5YTAETA4lkqehK7zJFVKPcekbV7L84Va",
		Cert:      "-----BEGIN CERTIFICATE-----\nMIIB9DCCAZigAwIBAgIELTs76TAMBggqhkjOPQQDAgUAMGYxCzAJBgNVBAYTAlVTMRcwFQYDVQQI Ew5Ob3J0aCBDYXJvbGluYTEZMBcGA1UEBxMQQXRvbWl6ZXJzIExpY2hlZTEPMA0GA1UEChMGTWFu aWFjMRIwEAYDVQQDEwlXaXNoZnVsbHkwHhcNMTUwOTEzMTExNDMzWhcNMTYwOTEyMTExNDMzWjBm MQswCQYDVQQGEwJVUzEXMBUGA1UECBMOTm9ydGggQ2Fyb2xpbmExGTAXBgNVBAcTEEF0b21pemVy cyBMaWNoZWUxDzANBgNVBAoTBk1hbmlhYzESMBAGA1UEAxMJV2lzaGZ1bGx5MFkwEwYHKoZIzj0C AQYIKoZIzj0DAQcDQgAE6j32mmT2hFkhxhHXC2tiNGggXIymmlp7RVRxd4FOwUYonDX+eFvTrScl Qx4dlfrNV6J8naYJlKJt0aamJ02BFKMyMDAwDwYDVR0RBAgwBocEvKZAnzAdBgNVHQ4EFgQUHpnj /4OvL/go+7bD0mj3Z7OOKvIwDAYIKoZIzj0EAwIFAANIADBFAiB9HOpnsV+aLqyNl0jOSDRTlKuD f6krUlzqbdm76ITqDAIhAJSku+5+G6V0ISc2Ciy0ip2G8wiirRDeAXo6eowCzgc0\n-----END CERTIFICATE-----\n",
		Weight:    1000000,
		Pipelined: true,
		QOS:       10,
		Trusted:   true,
	},
}

// defaultMasqueradeSets holds the default masquerades for fronted servers.
var defaultMasqueradeSets = map[string][]*fronted.Masquerade{
	// See masquerades.go
	cloudfront: cloudfrontMasquerades,
}
