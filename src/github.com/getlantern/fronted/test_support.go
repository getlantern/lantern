package fronted

import (
	"crypto/x509"
	"testing"

	"github.com/getlantern/keyman"
)

// ConfigureForTest configures fronted for testing using default masquerades and
// certificate authorities.
func ConfigureForTest(t *testing.T) {
	certs := trustedCACerts(t)
	m := make(map[string][]*Masquerade)
	m["cloudfront"] = DefaultCloudfrontMasquerades
	Configure(certs, m)
}

func trustedCACerts(t *testing.T) *x509.CertPool {
	certs := make([]string, 0, len(DefaultTrustedCAs))
	for _, ca := range DefaultTrustedCAs {
		certs = append(certs, ca.Cert)
	}
	pool, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		log.Errorf("Could not create pool %v", err)
		t.Fatalf("Unable to set up cert pool")
	}
	return pool
}
