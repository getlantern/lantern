package tlsdialer

import (
	"crypto/tls"
	"math/rand"
	"net"
	"testing"
	"time"

	"github.com/getlantern/fdcount"
	"github.com/getlantern/keyman"
	"github.com/stretchr/testify/assert"
)

const (
	ADDR              = "localhost:15623"
	CERTIFICATE_ERROR = "x509: certificate signed by unknown authority"
)

var (
	receivedServerNames = make(chan string)

	cert *keyman.Certificate
)

func init() {
	pk, err := keyman.GeneratePK(2048)
	if err != nil {
		log.Fatalf("Unable to generate key: %s", err)
	}

	// Generate self-signed certificate
	cert, err = pk.TLSCertificateFor("tlsdialer", "localhost", time.Now().Add(1*time.Hour), true, nil)
	if err != nil {
		log.Fatalf("Unable to generate cert: %s", err)
	}

	keypair, err := tls.X509KeyPair(cert.PEMEncoded(), pk.PEMEncoded())
	if err != nil {
		log.Fatalf("Unable to generate x509 key pair: %s", err)
	}

	listener, err := tls.Listen("tcp", ADDR, &tls.Config{
		Certificates: []tls.Certificate{keypair},
	})

	if err != nil {
		log.Fatalf("Unable to listen: %s", err)
	}

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				log.Fatalf("Unable to accept: %s", err)
			}
			go func() {
				tlsConn := conn.(*tls.Conn)
				// Discard this error, since we will use it for testing
				_ = tlsConn.Handshake()
				serverName := tlsConn.ConnectionState().ServerName
				if err := conn.Close(); err != nil {
					log.Fatalf("Unable to close connection: %v", err)
				}
				receivedServerNames <- serverName
			}()
		}
	}()
}

func TestOKWithServerName(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	cwt, err := DialForTimings(net.DialTimeout, 30*time.Second, "tcp", ADDR, true, &tls.Config{
		RootCAs: cert.PoolContainingCert(),
	})
	conn := cwt.Conn
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Equal(t, "localhost", serverName, "Unexpected ServerName on server")
	assert.NotNil(t, cwt.ResolvedAddr, "Should have resolved addr")

	closeAndCountFDs(t, conn, err, fdc)
}

func TestOKWithServerNameAndLongTimeout(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	conn, err := DialTimeout(net.DialTimeout, 25*time.Second, "tcp", ADDR, true, &tls.Config{
		RootCAs: cert.PoolContainingCert(),
	})
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Equal(t, "localhost", serverName, "Unexpected ServerName on server")

	closeAndCountFDs(t, conn, err, fdc)
}

func TestOKWithoutServerName(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	config := &tls.Config{
		RootCAs:    cert.PoolContainingCert(),
		ServerName: "localhost", // we manually set a ServerName to make sure it doesn't get sent
	}
	conn, err := Dial("tcp", ADDR, false, config)
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Empty(t, serverName, "Unexpected ServerName on server")
	assert.False(t, config.InsecureSkipVerify, "Original config shouldn't have been modified, but it was")

	closeAndCountFDs(t, conn, err, fdc)
}

func TestOKWithInsecureSkipVerify(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	conn, err := Dial("tcp", ADDR, false, &tls.Config{
		InsecureSkipVerify: true,
	})
	assert.NoError(t, err, "Unable to dial")
	<-receivedServerNames

	closeAndCountFDs(t, conn, err, fdc)
}

func TestNotOKWithServerName(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	conn, err := Dial("tcp", ADDR, true, nil)
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.Contains(t, err.Error(), CERTIFICATE_ERROR, "Wrong error on dial")
	}
	<-receivedServerNames

	closeAndCountFDs(t, conn, err, fdc)
}

func TestNotOKWithoutServerName(t *testing.T) {
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	conn, err := Dial("tcp", ADDR, true, &tls.Config{
		ServerName: "localhost",
	})
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.Contains(t, err.Error(), CERTIFICATE_ERROR, "Wrong error on dial")
	}
	serverName := <-receivedServerNames
	assert.Empty(t, serverName, "Unexpected ServerName on server")

	closeAndCountFDs(t, conn, err, fdc)
}

func TestNotOKWithBadRootCert(t *testing.T) {
	badCert, err := keyman.LoadCertificateFromPEMBytes([]byte(GoogleInternetAuthority))
	if err != nil {
		t.Fatalf("Unable to load GoogleInternetAuthority cert: %s", err)
	}

	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	conn, err := Dial("tcp", ADDR, true, &tls.Config{
		RootCAs: badCert.PoolContainingCert(),
	})
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.Contains(t, err.Error(), CERTIFICATE_ERROR, "Wrong error on dial")
	}
	<-receivedServerNames

	closeAndCountFDs(t, conn, err, fdc)
}

func TestVariableTimeouts(t *testing.T) {
	// Timeouts can happen in different places, run a bunch of randomized trials
	// to try to cover all of them.
	_, fdc, err := fdcount.Matching("TCP")
	if err != nil {
		t.Fatal(err)
	}

	doTestTimeout := func(timeout time.Duration) (didTimeout bool) {
		conn, err := DialTimeout(net.DialTimeout, timeout, "tcp", ADDR, false, &tls.Config{
			RootCAs: cert.PoolContainingCert(),
		})

		if err == nil {
			conn.Close()
			return false
		} else {
			if neterr, isNetError := err.(net.Error); isNetError {
				assert.True(t, neterr.Timeout(), "Dial error should be timeout", timeout)
			} else {
				t.Fatal(err)
			}
			return true
		}
	}

	// The 5000 microsecond limits is arbitrary. In some systems this may be too low/high.
	// The algorithm will try to adapt if connections succeed and will lower the current limit,
	// but it won't be allowed to timeout below the established lower boundary.
	timeoutMax := 5000
	numberOfTimeouts := 0
	for i := 0; i < 500; i++ {
		timeout := rand.Intn(timeoutMax) + 1
		didTimeout := doTestTimeout(time.Duration(timeout) * time.Microsecond)
		if didTimeout {
			numberOfTimeouts += 1
		} else {
			timeoutMax = int(float64(timeoutMax) * 0.75)
		}
	}
	assert.NotEqual(t, 0, numberOfTimeouts, "Should have timed out at least once")

	// Wait to give the sockets time to close
	time.Sleep(1 * time.Second)
	assert.NoError(t, fdc.AssertDelta(0), "Number of open files should be the same after test as before")
}

func closeAndCountFDs(t *testing.T, conn *tls.Conn, err error, fdc *fdcount.Counter) {
	if err == nil {
		if err := conn.Close(); err != nil {
			t.Fatalf("Unable to close connection: %v", err)
		}
	}
	assert.NoError(t, fdc.AssertDelta(0), "Number of open TCP files should be the same after test as before")
}

const GoogleInternetAuthority = `-----BEGIN CERTIFICATE-----
MIID8DCCAtigAwIBAgIDAjp2MA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT
MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
YWwgQ0EwHhcNMTMwNDA1MTUxNTU1WhcNMTYxMjMxMjM1OTU5WjBJMQswCQYDVQQG
EwJVUzETMBEGA1UEChMKR29vZ2xlIEluYzElMCMGA1UEAxMcR29vZ2xlIEludGVy
bmV0IEF1dGhvcml0eSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AJwqBHdc2FCROgajguDYUEi8iT/xGXAaiEZ+4I/F8YnOIe5a/mENtzJEiaB0C1NP
VaTOgmKV7utZX8bhBYASxF6UP7xbSDj0U/ck5vuR6RXEz/RTDfRK/J9U3n2+oGtv
h8DQUB8oMANA2ghzUWx//zo8pzcGjr1LEQTrfSTe5vn8MXH7lNVg8y5Kr0LSy+rE
ahqyzFPdFUuLH8gZYR/Nnag+YyuENWllhMgZxUYi+FOVvuOAShDGKuy6lyARxzmZ
EASg8GF6lSWMTlJ14rbtCMoU/M4iarNOz0YDl5cDfsCx3nuvRTPPuj5xt970JSXC
DTWJnZ37DhF5iR43xa+OcmkCAwEAAaOB5zCB5DAfBgNVHSMEGDAWgBTAephojYn7
qwVkDBF9qn1luMrMTjAdBgNVHQ4EFgQUSt0GFhu89mi1dvWBtrtiGrpagS8wEgYD
VR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAQYwNQYDVR0fBC4wLDAqoCig
JoYkaHR0cDovL2cuc3ltY2IuY29tL2NybHMvZ3RnbG9iYWwuY3JsMC4GCCsGAQUF
BwEBBCIwIDAeBggrBgEFBQcwAYYSaHR0cDovL2cuc3ltY2QuY29tMBcGA1UdIAQQ
MA4wDAYKKwYBBAHWeQIFATANBgkqhkiG9w0BAQUFAAOCAQEAJ4zP6cc7vsBv6JaE
+5xcXZDkd9uLMmCbZdiFJrW6nx7eZE4fxsggWwmfq6ngCTRFomUlNz1/Wm8gzPn6
8R2PEAwCOsTJAXaWvpv5Fdg50cUDR3a4iowx1mDV5I/b+jzG1Zgo+ByPF5E0y8tS
etH7OiDk4Yax2BgPvtaHZI3FCiVCUe+yOLjgHdDh/Ob0r0a678C/xbQF9ZR1DP6i
vgK66oZb+TWzZvXFjYWhGiN3GhkXVBNgnwvhtJwoKvmuAjRtJZOcgqgXe/GFsNMP
WOH7sf6coaPo/ck/9Ndx3L2MpBngISMjVROPpBYCCX65r+7bU2S9cS+5Oc4wt7S8
VOBHBw==
-----END CERTIFICATE-----`
