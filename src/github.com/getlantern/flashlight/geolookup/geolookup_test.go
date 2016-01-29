package geolookup

import (
	"crypto/x509"
	"testing"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/fronted"
	"github.com/getlantern/keyman"
)

func TestNonDefaultClient(t *testing.T) {
	Configure(eventual.DefaultGetter("localhost:8787"))
	rootCAs := certPool(t)
	masquerades := masquerades()

	m := make(map[string][]*fronted.Masquerade)
	m["cloudfront"] = masquerades
	fronted.Configure(rootCAs, m)
	country := GetCountry(5 * time.Second)
	ip := GetIP(5 * time.Second)
	if len(country) != 2 {
		t.Fatalf("Bad country %v for ip %v", country, ip)
	}

	if len(ip) < 7 {
		t.Fatalf("Bad IP %s", ip)
	}
}

type CA struct {
	CommonName string
	Cert       string
}

func certPool(t *testing.T) *x509.CertPool {
	var defaultTrustedCAs = []*CA{
		&CA{
			CommonName: "VeriSign Class 3 Public Primary Certification Authority - G5",
			Cert:       "-----BEGIN CERTIFICATE-----\nMIIE0zCCA7ugAwIBAgIQGNrRniZ96LtKIVjNzGs7SjANBgkqhkiG9w0BAQUFADCB\nyjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\nExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp\nU2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW\nZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0\naG9yaXR5IC0gRzUwHhcNMDYxMTA4MDAwMDAwWhcNMzYwNzE2MjM1OTU5WjCByjEL\nMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZW\nZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2ln\nbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJp\nU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9y\naXR5IC0gRzUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgIKXo1\nnmAMqudLO07cfLw8RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5Vbex\nt0uz/o9+B1fs70PbZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/WhkcIz\nSdhDY2pSS9KP6HBRTdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY5fQG\nBO+QueQA5N06tRn/Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT2RT+\nrCpSx4/VBEnkjWNHiDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMKz10/\nNIeWiu5T6CUVAgMBAAGjgbIwga8wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8E\nBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAH\nBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVy\naXNpZ24uY29tL3ZzbG9nby5naWYwHQYDVR0OBBYEFH/TZafC3ey78DAJ80M5+gKv\nMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQCTJEowX2LP2BqYLz3q3JktvXf2pXkiOOzE\np6B4Eq1iDkVwZMXnl2YtmAl+X6/WzChl8gGqCBpH3vn5fJJaCGkgDdk+bW48DW7Y\n5gaRQBi5+MHt39tBquCWIMnNZBU4gcmU7qKEKQsTb47bDN0lAtukixlE0kF6BWlK\nWE9gyn6CagsCqiUXObXbf+eEZSqVir2G3l6BFoMtEMze/aiCKm0oHw0LxOXnGiYZ\n4fQRbxC1lfznQgUy286dUV4otp6F01vvpX1FQHKOtw5rDgb7MzVIcbidJ4vEZV8N\nhnacRHr2lVz2XTIIM6RUthg/aFzyQkqFOFSDX9HoLPKsEdao7WNq\n-----END CERTIFICATE-----\n",
		},
	}
	certs := make([]string, 0, len(defaultTrustedCAs))
	for _, ca := range defaultTrustedCAs {
		certs = append(certs, ca.Cert)
	}
	pool, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Errorf("Could not create pool %v", err)
		t.Fatalf("Unable to set up cert pool")
	}
	return pool
}

func masquerades() []*fronted.Masquerade {
	var cloudfrontMasquerades = []*fronted.Masquerade{
		&fronted.Masquerade{
			Domain:    "Images-na.ssl-images-amazon.com",
			IpAddress: "54.230.0.233",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.15",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.7",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.12",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.122",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.160",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.166",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.178",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.183",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.204",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.211",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.230",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.135",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.249",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.158",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.190",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.52",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.59",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.90",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.97",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "205.251.203.208",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.97",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.13",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.119",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.150",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.153",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.152",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.162",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.160",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.164",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.175",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.180",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.115",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.184",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.19",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.147",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.149",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.199",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.211",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.21",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.207",
		},
	}
	return cloudfrontMasquerades
}
