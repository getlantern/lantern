package geolookup

import (
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
	d := integrationDialer(t, nil)
	defer func() {
		if err := d.Close(); err != nil {
			t.Fatalf("Unable to close dialer: %v", err)
		}
	}()

	client := d.NewDirectDomainFronter()
	city, _, err := LookupIPWithClient("198.199.72.101", client)
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

func integrationDialer(t *testing.T, statsFunc func(success bool, domain, addr string, resolutionTime, connectTime, handshakeTime time.Duration)) fronted.Dialer {
	rootCAs, err := keyman.PoolContainingCerts("-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkG\nA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jv\nb3QgQ0ExGzAZBgNVBAMTEkdsb2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAw\nMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9i\nYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYDVQQDExJHbG9iYWxT\naWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDaDuaZ\njc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavp\nxy0Sy6scTHAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp\n1Wrjsok6Vjk4bwY8iGlbKk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdG\nsnUOhugZitVtbNV4FpWi6cgKOOvyJBNPc1STE4U6G7weNLWLBYy5d4ux2x8gkasJ\nU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrXgzT/LCrBbBlDSgeF59N8\n9iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E\nBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0B\nAQUFAAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOz\nyj1hTdNGCbM+w6DjY1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE\n38NflNUVyRRBnMRddWQVDf9VMOyGj/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymP\nAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhHhm4qxFYxldBniYUr+WymXUad\nDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveCX4XSQRjbgbME\nHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==\n-----END CERTIFICATE-----\n")
	if err != nil {
		t.Fatalf("Unable to set up cert pool")
	}

	maxMasquerades := 2
	masquerades := make([]*fronted.Masquerade, maxMasquerades)
	for i := 0; i < len(masquerades); i++ {
		// Good masquerade with IP
		masquerades[i] = &fronted.Masquerade{
			Domain:    "10minutemail.com",
			IpAddress: "162.159.250.16",
		}
	}

	return fronted.NewDialer(fronted.Config{
		Host:           "no_difference_with_direct_domain_fronter.org",
		Port:           443,
		Masquerades:    masquerades,
		MaxMasquerades: maxMasquerades,
		RootCAs:        rootCAs,
		OnDialStats:    statsFunc,
	})
}
