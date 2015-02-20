// package globals contains global data accessible through the application
package globals

import (
	"crypto/x509"
	"github.com/getlantern/keyman"
)

var (
	InstanceId = ""
	Country    = "xx"
	TrustedCAs *x509.CertPool
)

func SetTrustedCAs(certs []string) error {
	newTrustedCAs, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		return err
	}
	TrustedCAs = newTrustedCAs
	return nil
}
