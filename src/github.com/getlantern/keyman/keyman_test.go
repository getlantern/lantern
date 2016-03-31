package keyman

import (
	"net"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

const (
	PK_FILE   = "testpk.pem"
	CERT_FILE = "testcert.pem"

	ONE_WEEK  = 7 * 24 * time.Hour
	TWO_WEEKS = ONE_WEEK * 2
)

func TestRoundTrip(t *testing.T) {
	defer func() {
		if err := os.Remove(PK_FILE); err != nil {
			log.Debugf("Unable to remove file: %v", err)
		}
	}()
	defer func() {
		if err := os.Remove(CERT_FILE); err != nil {
			log.Debugf("Unable to remove file: %v", err)
		}
	}()

	pk, err := GeneratePK(1024)
	assert.NoError(t, err, "Unable to generate PK")

	err = pk.WriteToFile(PK_FILE)
	assert.NoError(t, err, "Unable to save PK")

	pk2, err := LoadPKFromFile(PK_FILE)
	assert.NoError(t, err, "Unable to load PK")
	assert.Equal(t, pk.PEMEncoded(), pk2.PEMEncoded(), "Loaded PK didn't match saved PK")

	cert, err := pk.TLSCertificateFor("Test Org", "127.0.0.1", time.Now().Add(TWO_WEEKS), true, nil)
	assert.NoError(t, err, "Unable to generate self-signed certificate")

	numberOfIPSANs := len(cert.X509().IPAddresses)
	if numberOfIPSANs != 1 {
		t.Errorf("Wrong number of SANs, expected 1 got %d", numberOfIPSANs)
	} else {
		ip := cert.X509().IPAddresses[0]
		expectedIP := net.ParseIP("127.0.0.1")
		assert.Equal(t, expectedIP.String(), ip.String(), "Wrong IP SAN")
	}

	err = cert.WriteToFile(CERT_FILE)
	assert.NoError(t, err, "Unable to write certificate to file")

	cert2, err := LoadCertificateFromFile(CERT_FILE)
	assert.NoError(t, err, "Unable to load certificate from file")
	assert.Equal(t, cert.PEMEncoded(), cert2.PEMEncoded(), "Loaded certificate didn't match saved certificate")

	_, err = pk.Certificate(cert.X509(), cert)
	assert.NoError(t, err, "Unable to generate certificate signed by original certificate")

	pk3, err := GeneratePK(1024)
	assert.NoError(t, err, "Unable to generate PK 3")

	_, err = pk.CertificateForKey(cert.X509(), cert, &pk3.rsaKey.PublicKey)
	assert.NoError(t, err, "Unable to generate certificate for pk3")

	x509rt, err := LoadCertificateFromX509(cert.X509())
	assert.NoError(t, err, "Unable to load certificate from X509")
	assert.Equal(t, cert, x509rt, "X509 round tripped cert didn't match original")
}
