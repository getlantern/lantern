package fronted

import (
	"crypto/x509"
	"testing"
	"time"

	"github.com/getlantern/keyman"
)

func testEq(a, b []*Masquerade) bool {

	if a == nil && b == nil {
		return true
	}

	if a == nil || b == nil {
		return false
	}

	if len(a) != len(b) {
		return false
	}

	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}

	return true
}

func TestDirectDomainFronting(t *testing.T) {
	certs := trustedCACerts(t)
	m := make(map[string][]*Masquerade)
	m["cloudfront"] = cloudfrontMasquerades
	Configure(certs, m)

	client := NewDirectHttpClient(30 * time.Second)

	url := "https://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"
	if resp, err := client.Head(url); err != nil {
		t.Fatalf("Could not get response: %v", err)
	} else {
		if 200 != resp.StatusCode {
			t.Fatalf("Unexpected response status: %v", resp.StatusCode)
		}
	}

	log.Debugf("DIRECT DOMAIN FRONTING TEST SUCCEEDED")
}

func trustedCACerts(t *testing.T) *x509.CertPool {
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

type CA struct {
	CommonName string
	Cert       string
}

var defaultTrustedCAs = []*CA{
	&CA{
		CommonName: "VeriSign Class 3 Public Primary Certification Authority - G5",
		Cert:       "-----BEGIN CERTIFICATE-----\nMIIE0zCCA7ugAwIBAgIQGNrRniZ96LtKIVjNzGs7SjANBgkqhkiG9w0BAQUFADCB\nyjELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL\nExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJp\nU2lnbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxW\nZXJpU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0\naG9yaXR5IC0gRzUwHhcNMDYxMTA4MDAwMDAwWhcNMzYwNzE2MjM1OTU5WjCByjEL\nMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZW\nZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwNiBWZXJpU2ln\nbiwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MUUwQwYDVQQDEzxWZXJp\nU2lnbiBDbGFzcyAzIFB1YmxpYyBQcmltYXJ5IENlcnRpZmljYXRpb24gQXV0aG9y\naXR5IC0gRzUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCvJAgIKXo1\nnmAMqudLO07cfLw8RRy7K+D+KQL5VwijZIUVJ/XxrcgxiV0i6CqqpkKzj/i5Vbex\nt0uz/o9+B1fs70PbZmIVYc9gDaTY3vjgw2IIPVQT60nKWVSFJuUrjxuf6/WhkcIz\nSdhDY2pSS9KP6HBRTdGJaXvHcPaz3BJ023tdS1bTlr8Vd6Gw9KIl8q8ckmcY5fQG\nBO+QueQA5N06tRn/Arr0PO7gi+s3i+z016zy9vA9r911kTMZHRxAy3QkGSGT2RT+\nrCpSx4/VBEnkjWNHiDxpg8v+R70rfk/Fla4OndTRQ8Bnc+MUCH7lP59zuDMKz10/\nNIeWiu5T6CUVAgMBAAGjgbIwga8wDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8E\nBAMCAQYwbQYIKwYBBQUHAQwEYTBfoV2gWzBZMFcwVRYJaW1hZ2UvZ2lmMCEwHzAH\nBgUrDgMCGgQUj+XTGoasjY5rw8+AatRIGCx7GS4wJRYjaHR0cDovL2xvZ28udmVy\naXNpZ24uY29tL3ZzbG9nby5naWYwHQYDVR0OBBYEFH/TZafC3ey78DAJ80M5+gKv\nMzEzMA0GCSqGSIb3DQEBBQUAA4IBAQCTJEowX2LP2BqYLz3q3JktvXf2pXkiOOzE\np6B4Eq1iDkVwZMXnl2YtmAl+X6/WzChl8gGqCBpH3vn5fJJaCGkgDdk+bW48DW7Y\n5gaRQBi5+MHt39tBquCWIMnNZBU4gcmU7qKEKQsTb47bDN0lAtukixlE0kF6BWlK\nWE9gyn6CagsCqiUXObXbf+eEZSqVir2G3l6BFoMtEMze/aiCKm0oHw0LxOXnGiYZ\n4fQRbxC1lfznQgUy286dUV4otp6F01vvpX1FQHKOtw5rDgb7MzVIcbidJ4vEZV8N\nhnacRHr2lVz2XTIIM6RUthg/aFzyQkqFOFSDX9HoLPKsEdao7WNq\n-----END CERTIFICATE-----\n",
	},
}

var cloudflareMasquerades = []*Masquerade{}

var cloudfrontMasquerades = []*Masquerade{
	&Masquerade{
		Domain:    "Images-na.ssl-images-amazon.com",
		IpAddress: "54.230.0.233",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.15",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.7",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.12",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.122",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.160",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.166",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.178",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.183",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.204",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.211",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.230",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.135",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.249",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.158",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.190",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.52",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.59",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.90",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.97",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "205.251.203.208",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.97",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.13",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.119",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.150",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.153",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.152",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.162",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.160",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.164",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.175",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.180",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.115",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.184",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.19",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.147",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.149",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.199",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.211",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.21",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.207",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.204",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.209",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.216",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.232",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.235",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.245",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.248",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.68",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.32",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.34",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.4",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.46",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.217",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.5",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.51",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.77",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.79",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.87",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.88",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.92",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.99",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.96",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "216.137.39.219",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.100",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.102",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.106",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.105",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.11",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.112",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.115",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.119",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.120",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.121",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.127",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.125",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.122",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.124",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.132",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.134",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.138",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.141",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.146",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.148",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.15",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.150",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.152",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.153",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.157",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.161",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.165",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.167",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.168",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.20",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.24",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.22",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.21",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.26",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.29",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.33",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.30",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.37",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.36",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.41",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.38",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.46",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.45",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.48",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.51",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.56",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.63",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.69",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.61",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.66",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.71",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.73",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.76",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.78",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.8",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.87",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.85",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.89",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.93",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.94",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.96",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.97",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.182.4.98",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.10.83",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.3.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.3.34",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.192.7.168",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.169.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.10.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.191",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.19",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.10",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.134",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.138",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.69",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.156",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.18",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.11",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.200",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.205",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.215",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.223",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.22",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.227",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.246",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.27",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.45",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.13",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.132",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.243",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.62",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.7",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.9",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.4",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.40",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.6",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.24",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.93",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.67",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.61",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.230.6.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.130.187",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.10",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.100",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.103",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.102",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.104",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.106",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.107",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.11",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.109",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.110",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.111",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.112",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.114",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.115",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.116",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.117",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.118",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.12",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.120",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.119",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.121",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.105",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.122",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.123",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.101",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.125",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.124",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.126",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.128",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.129",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.130",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.131",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.13",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.132",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.134",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.133",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.135",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.137",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.138",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.14",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.139",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.140",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.141",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.144",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.143",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.148",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.147",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.145",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.142",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.15",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.150",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.149",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.151",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.152",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.153",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.154",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.155",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.157",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.156",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.158",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.16",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.164",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.161",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.162",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.165",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.163",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.159",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.167",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.166",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.168",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.169",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.171",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.17",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.170",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.172",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.173",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.175",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.176",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.177",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.178",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.146",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.179",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.18",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.182",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.181",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.185",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.189",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.188",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.186",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.184",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.187",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.191",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.190",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.192",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.194",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.195",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.193",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.196",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.197",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.199",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.198",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.200",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.20",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.201",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.202",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.204",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.205",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.207",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.209",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.208",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.21",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.206",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.210",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.212",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.211",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.213",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.214",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.215",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.22",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.218",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.221",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.217",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.216",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.220",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.222",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.226",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.225",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.224",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.228",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.223",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.227",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.180",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.229",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.231",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.23",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.232",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.203",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.236",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.235",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.234",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.233",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.237",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.238",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.24",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.239",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.240",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.243",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.246",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.244",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.248",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.242",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.241",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.245",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.247",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.249",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.25",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.251",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.19",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.252",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.254",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.27",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.29",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.26",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.30",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.250",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.31",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.33",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.32",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.35",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.183",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.36",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.38",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.37",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.39",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.4",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.44",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.40",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.41",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.47",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.43",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.45",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.42",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.48",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.230",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.50",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.5",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.49",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.51",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.53",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.57",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.56",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.55",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.58",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.59",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.60",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.62",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.63",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.6",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.61",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.65",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.68",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.66",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.64",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.67",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.71",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.76",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.7",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.69",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.253",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.73",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.74",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.77",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.78",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.79",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.81",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.83",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.89",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.82",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.80",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.85",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.84",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.86",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.93",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.92",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.91",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.90",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.97",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.98",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.46",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.96",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.52",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.54",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.72",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.88",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.8",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.9",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.94",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.95",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.194.64",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.192.99",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.100",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.101",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.104",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.103",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.105",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.106",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.102",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.107",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.111",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.109",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.112",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.66",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.67",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.69",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.68",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.71",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.73",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.99",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.76",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.98",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.56",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.96",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.158",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.148",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.71",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.67",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.78",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.77",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.53",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.5",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.99",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.74",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.55",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.52",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.93",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.54",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.50",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.95",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.98",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.96",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.97",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.66",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.51",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.98",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.79",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.94",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.81",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.80",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.92",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.91",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.90",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.57",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.56",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.9",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.89",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.58",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.88",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.83",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.87",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.239.204.72",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.49",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.86",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.84",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.85",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.81",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.82",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.80",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.8",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.239",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.79",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.238",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.237",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.236",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.78",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.77",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.159",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.74",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.72",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.76",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.73",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.63",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.59",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.65",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.64",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.60",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.61",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.62",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.6",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.48",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.47",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.42",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.44",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.45",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.41",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.43",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.46",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.40",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.197",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.198",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.35",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.36",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.196",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.199",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.4",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.37",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.38",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.34",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.39",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.33",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.221",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.234",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.30",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.235",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.3",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.32",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.31",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.29",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.233",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.192",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.26",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.252",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.253",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.254",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.189",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.27",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.25",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.250",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.251",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.249",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.248",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.247",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.246",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.245",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.244",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.243",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.242",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.241",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.240",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.24",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.188",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.232",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.231",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.182",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.230",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.23",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.229",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.228",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.226",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.227",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.224",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.222",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.223",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.219",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.220",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.22",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.225",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.218",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.217",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.214",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.215",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.172",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.183",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.213",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.210",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.211",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.212",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.209",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.207",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.206",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.21",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "204.246.164.42",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.171",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.169",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.208",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.205",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.204",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.203",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.200",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.201",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.202",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.20",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.2",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.195",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.193",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.194",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.184",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.186",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.185",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.187",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.181",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.104",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.105",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.180",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.18",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.179",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.178",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.173",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.176",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.177",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.174",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.175",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.103",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.17",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.170",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.167",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.168",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.166",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.161",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.164",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.163",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.162",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.165",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.160",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.100",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.159",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.16",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.158",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.101",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.157",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.99",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.95",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.152",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.156",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.153",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.154",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.151",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.150",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.15",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.155",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.149",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.147",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.148",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.146",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.143",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.145",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.142",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.144",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.140",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.141",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.45",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.14",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.137",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.138",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.139",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.135",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.134",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.122",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.13",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.132",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.130",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.124",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.129",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.127",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.128",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.10",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.133",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.100",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.123",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.101",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.102",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.103",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.105",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.107",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.104",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.106",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.115",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.116",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.114",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.109",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.11",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.112",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.111",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.110",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.117",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.119",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.118",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.120",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.12",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.123",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.122",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.121",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.124",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.125",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.127",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.128",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.129",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.126",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.13",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.130",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.132",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.133",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.136",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.139",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.138",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.14",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.140",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.141",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.143",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.142",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.147",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.150",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.152",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.151",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.168",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.167",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.169",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.137",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.135",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.170",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.17",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.171",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.172",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.15",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.149",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.173",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.174",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.175",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.125",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.153",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.179",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.144",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.18",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.178",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.176",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.181",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.180",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.177",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.182",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.183",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.184",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.185",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.187",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.186",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.145",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.188",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.146",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.189",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.19",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.193",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.190",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.194",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.195",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.191",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.192",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.196",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.197",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.199",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.198",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.156",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.2",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.157",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.155",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.20",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.16",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.126",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.200",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.203",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.204",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.202",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.94",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.206",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.209",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.207",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.201",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.205",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.208",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.21",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.161",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.160",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.211",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.210",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.212",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.213",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.163",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.162",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.166",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.165",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.215",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.216",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.164",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.217",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.214",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.218",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.219",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.22",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.220",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.222",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.223",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.224",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.225",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.221",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.230",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.228",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.227",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.226",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.23",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.229",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.231",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.232",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.234",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.233",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.237",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.236",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.235",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.238",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.24",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.239",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.240",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.246",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.243",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.242",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.241",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.247",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.25",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.249",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.248",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.245",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.244",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.252",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.251",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.121",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.250",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.28",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.253",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.254",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.26",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.29",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.27",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.30",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.3",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.120",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.32",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.43",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.36",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.31",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.35",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.33",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.34",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.42",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.47",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.48",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.46",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.5",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.50",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.49",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.52",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.51",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.53",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.54",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.57",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.58",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.6",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.59",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.62",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.64",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.63",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.66",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.65",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.61",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.60",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.67",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.68",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.7",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.38",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.37",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.72",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.73",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.70",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.71",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.74",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.4",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.69",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.119",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.12",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.39",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.75",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.76",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.77",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.40",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.79",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.55",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.8",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.81",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.80",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.85",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.86",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.90",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.88",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.87",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.93",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.91",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.9",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.89",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.44",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.92",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.106",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.107",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.41",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.84",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.108",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.111",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.109",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.11",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.116",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.113",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.112",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.110",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.115",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.114",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.118",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.78",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.131.117",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.82",
	},
	&Masquerade{
		Domain:    "cloudfront.net",
		IpAddress: "54.240.130.83",
	},
	&Masquerade{
		Domain:    "d1ahq84kgt5vd1.cloudfront.net",
		IpAddress: "204.246.169.15",
	},
	&Masquerade{
		Domain:    "d1jwpcr0q4pcq0.cloudfront.net",
		IpAddress: "54.230.10.20",
	},
	&Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "205.251.203.218",
	},
	&Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "216.137.39.247",
	},
	&Masquerade{
		Domain:    "d1rucrevwzgc5t.cloudfront.net",
		IpAddress: "54.192.3.180",
	},
	&Masquerade{
		Domain:    "d3tyii1ml8c0t0.cloudfront.net",
		IpAddress: "54.230.10.192",
	},
	&Masquerade{
		Domain:    "dariffnjgq54b.cloudfront.net",
		IpAddress: "204.246.169.126",
	},
	&Masquerade{
		Domain:    "dmnso1wfcoh34.cloudfront.net",
		IpAddress: "54.230.10.32",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.120",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.99",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.111",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.98",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.95",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.96",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.97",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.92",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.93",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.94",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.88",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.89",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.91",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.9",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.90",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.87",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.8",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.12",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.83",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.81",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.84",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.86",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.85",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.11",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.82",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.80",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.74",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.78",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.77",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.79",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.76",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.75",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.72",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.73",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.70",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.71",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.67",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.68",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.69",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.7",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.64",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.65",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.66",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.62",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.61",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.63",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.60",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.59",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.6",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.58",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.53",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.54",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.56",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.52",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.57",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.55",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.51",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.114",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.49",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.5",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.50",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.47",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.48",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.45",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.46",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.43",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.41",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.44",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.42",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.39",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.38",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.40",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.4",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.113",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.37",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.36",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.35",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.33",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.32",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.34",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.30",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.31",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.3",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.27",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.28",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.29",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.254",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.253",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.26",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.252",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.25",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.249",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.250",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.248",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.212",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.130",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.210",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.21",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.247",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.245",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.244",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.246",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.243",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.242",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.241",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.240",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.208",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.209",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.24",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.207",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.206",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.128",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.239",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.238",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.237",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.193",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.236",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.233",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.126",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.234",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.195",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.232",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.119",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.235",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.127",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.196",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.125",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.231",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.197",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.124",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.230",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.23",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.194",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.229",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.228",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.227",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.225",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.226",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.224",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.221",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.223",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.222",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.220",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.218",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.219",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.22",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.217",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.216",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.215",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.202",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.214",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.2",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.201",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.205",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.200",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.213",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.204",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.191",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.192",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.203",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.20",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.123",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.198",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.199",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.190",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.122",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.19",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.189",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.186",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.117",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.187",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.183",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.185",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.184",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.180",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.181",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.177",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.182",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.115",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.178",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.179",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.18",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.176",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.175",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.174",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.17",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.104",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.172",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.173",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.169",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.170",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.171",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.168",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.167",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.166",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.164",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.165",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.163",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.160",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.16",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.161",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.155",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.159",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.158",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.162",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.157",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.156",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.15",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.150",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.151",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.152",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.154",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.153",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.149",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.148",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.147",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.10",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.100",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.146",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.145",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.142",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.140",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.101",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.144",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.143",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.141",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.14",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.139",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.102",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.138",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.137",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.136",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.129",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.134",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.135",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.133",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.13",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.251",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.112",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.121",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.109",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.105",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.108",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.106",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.116",
	},
	&Masquerade{
		Domain:    "www.cloudfront.net",
		IpAddress: "54.240.129.211",
	},
}
