package tlsdefaults

import (
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/getlantern/keyman"
)

var (
	tenYearsFromToday = time.Now().AddDate(10, 0, 0)
)

// Listen opens a TLS listener at the given address using the private key and
// certificate PEM files at the given paths. If no files exists, it creates a
// new key and self-signed certificate at those locations.
func Listen(addr, pkfile, certfile string) (net.Listener, error) {
	l, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, fmt.Errorf("Unable to listen for connections at %s: %s\n", addr, err)
	}

	return NewListener(l, pkfile, certfile)
}

// NewListener creates a TLS listener based on the given listener using the
// private key and certificate PEM files at the given paths. If no files exists,
// it creates a new key and self-signed certificate at those locations.
func NewListener(l net.Listener, pkfile, certfile string) (net.Listener, error) {
	addr := l.Addr().String()
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return nil, fmt.Errorf("Unable to split host and port for %v: %v\n", addr, err)
	}

	mypkfile := pkfile
	if mypkfile == "" {
		mypkfile = "key.pem"
	}
	mycertfile := certfile
	if mycertfile == "" {
		mycertfile = "cert.pem"
	}
	ctx := CertContext{
		PKFile:         mypkfile,
		ServerCertFile: mycertfile,
	}
	_, err1 := os.Stat(ctx.ServerCertFile)
	_, err2 := os.Stat(ctx.PKFile)
	if os.IsNotExist(err1) || os.IsNotExist(err2) {
		fmt.Println("At least one of the Key/Cert files is not found -> Generating new key pair")
		err = ctx.initServerCert(host)
		if err != nil {
			return nil, fmt.Errorf("Unable to init server cert: %s\n", err)
		}
	} /* else if *debug {
	    fmt.Println("Using provided Key/Cert files")
	}*/

	tlsConfig := Server()
	cert, err := tls.LoadX509KeyPair(ctx.ServerCertFile, ctx.PKFile)
	if err != nil {
		return nil, fmt.Errorf("Unable to load certificate and key from %s and %s: %s\n", ctx.ServerCertFile, ctx.PKFile, err)
	}
	tlsConfig.Certificates = []tls.Certificate{cert}

	return tls.NewListener(l, tlsConfig), nil
}

// CertContext encapsulates the certificates used by a Server
type CertContext struct {
	PKFile         string
	ServerCertFile string
	PK             *keyman.PrivateKey
	ServerCert     *keyman.Certificate
}

// InitServerCert initializes a PK + cert for use by a server proxy, signed by
// the CA certificate.  We always generate a new certificate just in case.
func (ctx *CertContext) initServerCert(host string) (err error) {
	if ctx.PK, err = keyman.LoadPKFromFile(ctx.PKFile); err != nil {
		if os.IsNotExist(err) {
			fmt.Printf("Creating new PK at: %s\n", ctx.PKFile)
			if ctx.PK, err = keyman.GeneratePK(2048); err != nil {
				return
			}
			if err = ctx.PK.WriteToFile(ctx.PKFile); err != nil {
				return fmt.Errorf("Unable to save private key: %s\n", err)
			}
		} else {
			return fmt.Errorf("Unable to read private key, even though it exists: %s\n", err)
		}
	}

	fmt.Printf("Creating new server cert at: %s\n", ctx.ServerCertFile)
	ctx.ServerCert, err = ctx.PK.TLSCertificateFor("Lantern", host, tenYearsFromToday, true, nil)
	if err != nil {
		return
	}
	err = ctx.ServerCert.WriteToFile(ctx.ServerCertFile)
	if err != nil {
		return
	}
	return nil
}
