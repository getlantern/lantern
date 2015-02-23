// package globals contains global data accessible through the application
package globals

import (
	"crypto/x509"
	"sync/atomic"

	"github.com/getlantern/geolookup"
	"github.com/getlantern/keyman"
)

var (
	InstanceId = ""
	TrustedCAs *x509.CertPool

	location atomic.Value
)

func SetLocation(loc *geolookup.City) {
	location.Store(loc)
}

func GetLocation() *geolookup.City {
	l := location.Load()
	if l == nil {
		return nil
	}
	return l.(*geolookup.City)
}

func GetCountry() string {
	loc := GetLocation()
	if loc == nil {
		return ""
	}
	return loc.Country.IsoCode
}

func SetTrustedCAs(certs []string) error {
	newTrustedCAs, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		return err
	}
	TrustedCAs = newTrustedCAs
	return nil
}
