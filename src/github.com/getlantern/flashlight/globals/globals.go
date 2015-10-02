// package globals contains global data accessible through the application
package globals

var (
	InstanceId = ""

//	TrustedCAs *x509.CertPool
)

/*
func SetTrustedCAs(certs []string) error {
	newTrustedCAs, err := keyman.PoolContainingCerts(certs...)
	if err != nil {
		return err
	}
	TrustedCAs = newTrustedCAs
	return nil
}
*/
