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
	"fallback-128.199.42.142": &client.ChainedServerInfo{
		Addr:      "128.199.42.142:443",
		AuthToken: "tKPlcDVuahj3xQbfFL0RBq9awr2fbgDZRjl2xOul1myiZ1eqrZ0JA1p9Z7ilIY6V",
		Cert:      "-----BEGIN CERTIFICATE-----\n MIIFCDCCAvCgAwIBAgIEUcjMBzANBgkqhkiG9w0BAQsFADAsMRcwFQYDVQQKEw5SaWJzIFNwaW5k bGllcjERMA8GA1UEAxMIQ3JlYW1lcnkwHhcNMTUwNjEwMTYxNDU2WhcNMTcwNjA5MTYxNDU2WjAs MRcwFQYDVQQKEw5SaWJzIFNwaW5kbGllcjERMA8GA1UEAxMIQ3JlYW1lcnkwggIiMA0GCSqGSIb3 DQEBAQUAA4ICDwAwggIKAoICAQCUJ3L2I0FZFPbxPSvIh4K63mmkRGK+3RN8XCBZAri0hTQ+30h/ y8RCv+tpkSx9uQy1O2xM6z3ipSJJ8aUqIoDwdNthZqKUV+Oa0rR6qYe3eD/ZqSB6wS415fKOwdSA KTbuHlu5B58mtx5BTnnRne0Kk9VGhUfYclIzSEPfeOCDaiTDgPVDlB15FvwhB3Ic9Vz+tc5P4MdO U0hjR8oibCWZqhJW89bePAhKPZHjR6HtXlZaC0y4nkev1BXLbn5L3CyxzafgRwBTtVyKef5lonWN 9ByV2pVZNMAB0pCGJBon7sDQaSCul9wIuslebiMNTGDlwcHYfQHPtKU3yG32n21sWZQla2LKL8F5 gnn5FkQ2XQrrRW9jxnsoY62zn1yolduew7PUGMjAFZ/GJANIQ6W1ph3rUSqoBqTDoKmvgTdQRblM jGGTQ5i8aLkpX95QyaEHOlmlq/EkEGvDwinAPEYN8qVMnVwYqASJwMI9Ko2lVGan6Ci1Pn7RyBbY jqPWc33G8tPxteC1bZnZfhJgPrnU/BRLk9MO36Ws52yJtymMTVV48Za4BC9di9kEOXahpIEQq9aO REcicSiHoigifSGN9gS+5IL1NmZw/mW/sWCDmHx7npaFdO3580+mCZKM3OOjLZwjx5kM/ePSreho 9WbUsjGWiHvwry/1zeJ4mIKbYwIDAQABozIwMDAPBgNVHREECDAGhwSAxyqOMB0GA1UdDgQWBBTq yNjIDQqe0zKIGHwRSFThqQVCijANBgkqhkiG9w0BAQsFAAOCAgEAdSZx1BjlJVj2VFKT0gIZL44E UtTXjbh1L4Hw6IOE/k8FfL6z//a+dTAlkSbbfg/6+WgIScQjKzjrW2FA/W+K4fEJkkRJ81JdAZQk RpZOIUtfVJocp7FAiljtbMOA5OgygynB3oDNIzoRI7eE4uUNHKp2x+fNkGTjRjxcbOk6he+NSpbH +BuynMz55tEG3qsa8/WKLVHrMK9W8s11bOkxcb9ww6xnpwWZFbNO7lef1BBMxqFfkl7CGoFIz13z C6Zd5M2+NCmVxJKV+0zU8wzm+jLrr9X/dHCbhHObBphFeEsAL1m9xnePTAySKU7I74oF2mAuuowR FE2fdlg0cFwGyKY02rg1T5xvFbappOOwHUa13IyjfdS7SzvzVzG/SmuKUxB9MX3vkw59RvwZnnh1 TmGpXN7sakzfzxCXUcUlIQAI8E03F+g4m997L+HVPEj/n12DUZ3VQrQmtSvk992i4J+BpyY8zKho HdQm/6RjFoYLRWXYzm7G7wGAhZdHPJetYk3Kz9AIbugXfueQNwZPL24k/89n5d4rsil79WyWasYW ECJP8GEbFYCgFmNvhAjJsSaFCHCwh70bK1T0YyESwhW7bRZ3tmYABOzMw6Lphya1xcYhs9MTEQBK 7z6lw//mLPN13oiwtQ9ZFtJg8XxffBpJ7KW2HSBsQI6EgK3Iv6g=\n-----END CERTIFICATE-----\n",
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
