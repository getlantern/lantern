package geolookup

import (
	"crypto/x509"
	"fmt"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/getlantern/fronted"
	"github.com/getlantern/keyman"
	"github.com/getlantern/testify/assert"
)

func TestCityLookup(t *testing.T) {
	client := &http.Client{}
	city, _, err := LookupIPWithClient("198.199.72.101", client)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])

	}

	// Now test with direct domain fronting.
	rootCAs := certPool(t)
	masquerades := masquerades()

	m := make(map[string][]*fronted.Masquerade)
	m["cloudfront"] = masquerades
	fronted.Configure(rootCAs, m)
	log.Debugf("Configured fronted")
	client = fronted.NewDirectHttpClient(30 * time.Second)
	cloudfrontEndpoint := `http://d3u5fqukq7qrhd.cloudfront.net/lookup/%v`

	log.Debugf("Looking up IP with CloudFront")
	city, _, err = LookupIPWithEndpoint(cloudfrontEndpoint, "198.199.72.101", client)
	if assert.NoError(t, err) {
		assert.Equal(t, "New York", city.City.Names["en"])
	}
}

func TestNonDefaultClient(t *testing.T) {
	// Set up a client that will fail
	client := &http.Client{
		Transport: &http.Transport{
			Dial: func(network, addr string) (net.Conn, error) {
				return nil, fmt.Errorf("Failing intentionally")
			},
		},
	}

	_, _, err := LookupIPWithClient("", client)
	assert.Error(t, err, "Using bad client should have resulted in error")
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
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.204",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.209",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.216",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.232",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.235",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.245",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.248",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.68",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.32",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.34",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.4",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.46",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.217",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.5",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.51",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.77",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.79",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.87",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.88",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.92",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.99",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.96",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "216.137.39.219",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.100",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.102",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.106",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.105",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.11",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.112",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.115",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.119",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.120",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.121",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.127",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.125",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.122",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.124",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.132",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.134",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.138",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.141",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.146",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.148",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.15",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.150",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.152",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.153",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.157",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.161",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.165",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.167",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.168",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.20",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.24",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.22",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.21",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.26",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.29",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.33",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.30",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.37",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.36",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.41",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.38",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.46",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.45",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.48",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.51",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.56",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.63",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.69",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.61",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.66",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.71",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.73",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.76",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.78",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.8",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.87",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.85",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.89",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.93",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.94",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.96",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.97",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.182.4.98",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.192.10.83",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.192.3.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.192.3.34",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.192.7.168",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.169.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.10.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.191",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.19",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.10",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.134",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.138",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.69",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.156",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.18",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.11",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.200",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.205",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.215",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.223",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.22",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.227",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.246",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.27",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.45",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.13",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.132",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.243",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.62",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.7",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.9",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.4",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.40",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.6",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.24",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.93",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.67",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.61",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.230.6.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.130.187",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.10",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.100",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.103",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.102",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.104",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.106",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.107",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.11",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.109",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.110",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.111",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.112",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.114",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.115",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.116",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.117",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.118",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.12",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.120",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.119",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.121",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.105",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.122",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.123",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.101",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.125",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.124",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.126",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.128",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.129",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.130",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.131",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.13",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.132",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.134",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.133",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.135",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.137",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.138",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.14",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.139",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.140",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.141",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.144",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.143",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.148",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.147",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.145",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.142",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.15",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.150",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.149",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.151",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.152",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.153",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.154",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.155",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.157",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.156",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.158",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.16",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.164",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.161",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.162",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.165",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.163",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.159",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.167",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.166",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.168",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.169",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.171",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.17",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.170",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.172",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.173",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.175",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.176",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.177",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.178",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.146",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.179",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.18",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.182",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.181",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.185",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.189",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.188",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.186",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.184",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.187",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.191",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.190",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.192",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.194",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.195",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.193",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.196",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.197",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.199",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.198",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.200",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.20",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.201",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.202",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.204",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.205",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.207",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.209",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.208",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.21",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.206",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.210",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.212",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.211",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.213",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.214",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.215",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.22",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.218",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.221",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.217",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.216",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.220",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.222",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.226",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.225",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.224",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.228",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.223",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.227",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.180",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.229",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.231",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.23",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.232",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.203",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.236",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.235",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.234",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.233",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.237",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.238",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.24",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.239",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.240",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.243",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.246",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.244",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.248",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.242",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.241",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.245",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.247",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.249",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.25",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.251",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.19",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.252",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.254",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.27",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.29",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.26",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.30",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.250",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.31",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.33",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.32",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.35",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.183",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.36",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.38",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.37",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.39",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.4",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.44",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.40",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.41",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.47",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.43",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.45",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.42",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.48",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.230",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.50",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.5",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.49",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.51",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.53",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.57",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.56",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.55",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.58",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.59",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.60",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.62",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.63",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.6",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.61",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.65",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.68",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.66",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.64",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.67",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.71",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.76",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.7",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.69",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.253",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.73",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.74",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.77",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.78",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.79",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.81",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.83",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.89",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.82",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.80",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.85",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.84",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.86",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.93",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.92",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.91",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.90",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.97",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.98",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.46",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.96",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.52",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.54",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.72",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.88",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.8",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.9",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.94",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.95",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.194.64",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.192.99",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.100",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.101",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.104",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.103",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.105",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.106",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.102",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.107",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.111",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.109",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.112",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.66",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.67",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.69",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.68",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.71",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.73",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.99",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.76",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.98",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.56",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.96",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.158",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.148",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.71",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.67",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.78",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.77",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.53",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.5",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.99",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.74",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.55",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.52",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.93",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.54",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.50",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.95",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.98",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.96",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.97",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.66",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.51",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.98",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.79",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.94",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.81",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.80",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.92",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.91",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.90",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.57",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.56",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.9",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.89",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.58",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.88",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.83",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.87",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.239.204.72",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.49",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.86",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.84",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.85",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.81",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.82",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.80",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.8",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.239",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.79",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.238",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.237",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.236",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.78",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.77",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.159",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.74",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.72",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.76",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.73",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.63",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.59",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.65",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.64",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.60",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.61",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.62",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.6",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.48",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.47",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.42",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.44",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.45",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.41",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.43",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.46",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.40",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.197",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.198",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.35",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.36",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.196",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.199",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.4",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.37",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.38",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.34",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.39",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.33",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.221",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.234",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.30",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.235",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.3",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.32",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.31",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.29",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.233",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.192",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.26",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.252",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.253",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.254",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.189",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.27",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.25",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.250",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.251",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.249",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.248",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.247",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.246",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.245",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.244",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.243",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.242",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.241",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.240",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.24",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.188",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.232",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.231",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.182",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.230",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.23",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.229",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.228",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.226",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.227",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.224",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.222",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.223",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.219",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.220",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.22",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.225",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.218",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.217",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.214",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.215",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.172",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.183",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.213",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.210",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.211",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.212",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.209",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.207",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.206",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.21",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "204.246.164.42",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.171",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.169",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.208",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.205",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.204",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.203",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.200",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.201",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.202",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.20",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.2",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.195",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.193",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.194",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.184",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.186",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.185",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.187",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.181",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.104",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.105",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.180",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.18",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.179",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.178",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.173",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.176",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.177",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.174",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.175",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.103",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.17",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.170",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.167",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.168",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.166",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.161",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.164",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.163",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.162",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.165",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.160",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.100",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.159",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.16",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.158",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.101",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.157",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.99",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.95",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.152",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.156",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.153",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.154",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.151",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.150",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.15",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.155",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.149",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.147",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.148",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.146",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.143",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.145",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.142",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.144",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.140",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.141",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.45",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.14",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.137",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.138",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.139",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.135",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.134",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.122",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.13",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.132",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.130",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.124",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.129",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.127",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.128",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.10",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.133",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.100",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.123",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.101",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.102",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.103",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.105",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.107",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.104",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.106",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.115",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.116",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.114",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.109",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.11",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.112",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.111",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.110",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.117",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.119",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.118",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.120",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.12",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.123",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.122",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.121",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.124",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.125",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.127",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.128",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.129",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.126",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.13",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.130",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.132",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.133",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.136",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.139",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.138",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.14",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.140",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.141",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.143",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.142",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.147",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.150",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.152",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.151",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.168",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.167",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.169",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.137",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.135",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.170",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.17",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.171",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.172",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.15",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.149",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.173",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.174",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.175",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.125",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.153",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.179",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.144",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.18",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.178",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.176",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.181",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.180",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.177",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.182",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.183",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.184",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.185",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.187",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.186",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.145",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.188",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.146",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.189",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.19",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.193",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.190",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.194",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.195",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.191",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.192",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.196",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.197",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.199",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.198",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.156",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.2",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.157",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.155",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.20",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.16",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.126",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.200",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.203",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.204",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.202",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.94",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.206",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.209",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.207",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.201",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.205",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.208",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.21",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.161",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.160",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.211",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.210",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.212",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.213",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.163",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.162",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.166",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.165",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.215",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.216",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.164",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.217",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.214",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.218",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.219",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.22",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.220",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.222",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.223",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.224",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.225",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.221",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.230",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.228",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.227",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.226",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.23",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.229",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.231",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.232",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.234",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.233",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.237",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.236",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.235",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.238",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.24",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.239",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.240",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.246",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.243",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.242",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.241",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.247",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.25",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.249",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.248",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.245",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.244",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.252",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.251",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.121",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.250",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.28",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.253",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.254",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.26",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.29",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.27",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.30",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.3",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.120",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.32",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.43",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.36",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.31",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.35",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.33",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.34",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.42",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.47",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.48",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.46",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.5",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.50",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.49",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.52",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.51",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.53",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.54",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.57",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.58",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.6",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.59",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.62",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.64",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.63",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.66",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.65",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.61",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.60",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.67",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.68",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.7",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.38",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.37",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.72",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.73",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.70",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.71",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.74",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.4",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.69",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.119",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.12",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.39",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.75",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.76",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.77",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.40",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.79",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.55",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.8",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.81",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.80",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.85",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.86",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.90",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.88",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.87",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.93",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.91",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.9",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.89",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.44",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.92",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.106",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.107",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.41",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.84",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.108",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.111",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.109",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.11",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.116",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.113",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.112",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.110",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.115",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.114",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.118",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.78",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.131.117",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.82",
		},
		&fronted.Masquerade{
			Domain:    "cloudfront.net",
			IpAddress: "54.240.130.83",
		},
		&fronted.Masquerade{
			Domain:    "d1ahq84kgt5vd1.cloudfront.net",
			IpAddress: "204.246.169.15",
		},
		&fronted.Masquerade{
			Domain:    "d1jwpcr0q4pcq0.cloudfront.net",
			IpAddress: "54.230.10.20",
		},
		&fronted.Masquerade{
			Domain:    "d1rucrevwzgc5t.cloudfront.net",
			IpAddress: "205.251.203.218",
		},
		&fronted.Masquerade{
			Domain:    "d1rucrevwzgc5t.cloudfront.net",
			IpAddress: "216.137.39.247",
		},
		&fronted.Masquerade{
			Domain:    "d1rucrevwzgc5t.cloudfront.net",
			IpAddress: "54.192.3.180",
		},
		&fronted.Masquerade{
			Domain:    "d3tyii1ml8c0t0.cloudfront.net",
			IpAddress: "54.230.10.192",
		},
		&fronted.Masquerade{
			Domain:    "dariffnjgq54b.cloudfront.net",
			IpAddress: "204.246.169.126",
		},
		&fronted.Masquerade{
			Domain:    "dmnso1wfcoh34.cloudfront.net",
			IpAddress: "54.230.10.32",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.120",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.99",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.111",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.98",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.95",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.96",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.97",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.92",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.93",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.94",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.88",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.89",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.91",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.9",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.90",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.87",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.8",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.12",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.83",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.81",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.84",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.86",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.85",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.11",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.82",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.80",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.74",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.78",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.77",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.79",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.76",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.75",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.72",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.73",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.70",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.71",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.67",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.68",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.69",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.7",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.64",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.65",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.66",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.62",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.61",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.63",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.60",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.59",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.6",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.58",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.53",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.54",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.56",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.52",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.57",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.55",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.51",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.114",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.49",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.5",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.50",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.47",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.48",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.45",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.46",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.43",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.41",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.44",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.42",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.39",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.38",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.40",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.4",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.113",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.37",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.36",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.35",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.33",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.32",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.34",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.30",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.31",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.3",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.27",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.28",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.29",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.254",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.253",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.26",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.252",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.25",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.249",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.250",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.248",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.212",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.130",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.210",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.21",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.247",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.245",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.244",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.246",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.243",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.242",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.241",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.240",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.208",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.209",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.24",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.207",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.206",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.128",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.239",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.238",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.237",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.193",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.236",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.233",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.126",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.234",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.195",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.232",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.119",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.235",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.127",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.196",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.125",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.231",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.197",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.124",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.230",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.23",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.194",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.229",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.228",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.227",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.225",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.226",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.224",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.221",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.223",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.222",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.220",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.218",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.219",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.22",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.217",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.216",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.215",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.202",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.214",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.2",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.201",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.205",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.200",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.213",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.204",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.191",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.192",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.203",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.20",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.123",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.198",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.199",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.190",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.122",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.19",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.189",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.186",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.117",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.187",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.183",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.185",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.184",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.180",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.181",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.177",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.182",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.115",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.178",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.179",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.18",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.176",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.175",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.174",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.17",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.104",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.172",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.173",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.169",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.170",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.171",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.168",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.167",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.166",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.164",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.165",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.163",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.160",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.16",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.161",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.155",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.159",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.158",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.162",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.157",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.156",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.15",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.150",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.151",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.152",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.154",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.153",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.149",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.148",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.147",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.10",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.100",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.146",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.145",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.142",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.140",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.101",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.144",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.143",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.141",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.14",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.139",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.102",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.138",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.137",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.136",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.129",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.134",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.135",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.133",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.13",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.251",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.112",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.121",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.109",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.105",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.108",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.106",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.116",
		},
		&fronted.Masquerade{
			Domain:    "www.cloudfront.net",
			IpAddress: "54.240.129.211",
		},
	}
	return cloudfrontMasquerades
}
