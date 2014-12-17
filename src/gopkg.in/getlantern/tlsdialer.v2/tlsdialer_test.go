package tlsdialer

import (
	"bytes"
	"crypto/tls"
	"fmt"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/getlantern/keyman"
	"github.com/getlantern/testify/assert"
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
				tlsConn.Handshake()
				serverName := tlsConn.ConnectionState().ServerName
				conn.Close()
				receivedServerNames <- serverName
			}()
		}
	}()
}

func TestOKWithServerName(t *testing.T) {
	fdStart := countTCPFiles()
	cwt, err := DialForTimings(new(net.Dialer), "tcp", ADDR, true, &tls.Config{
		RootCAs: cert.PoolContainingCert(),
	})
	conn := cwt.Conn
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Equal(t, "localhost", serverName, "Unexpected ServerName on server")
	assert.NotNil(t, cwt.ResolvedAddr, "Should have resolved addr")
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestOKWithServerNameAndLongTimeout(t *testing.T) {
	fdStart := countTCPFiles()
	conn, err := DialWithDialer(&net.Dialer{
		Timeout: 25 * time.Second,
	}, "tcp", ADDR, true, &tls.Config{
		RootCAs: cert.PoolContainingCert(),
	})
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Equal(t, "localhost", serverName, "Unexpected ServerName on server")
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestOKWithoutServerName(t *testing.T) {
	fdStart := countTCPFiles()
	config := &tls.Config{
		RootCAs:    cert.PoolContainingCert(),
		ServerName: "localhost", // we manually set a ServerName to make sure it doesn't get sent
	}
	conn, err := Dial("tcp", ADDR, false, config)
	assert.NoError(t, err, "Unable to dial")
	serverName := <-receivedServerNames
	assert.Empty(t, serverName, "Unexpected ServerName on server")
	assert.False(t, config.InsecureSkipVerify, "Original config shouldn't have been modified, but it was")
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestOKWithInsecureSkipVerify(t *testing.T) {
	fdStart := countTCPFiles()
	conn, err := Dial("tcp", ADDR, false, &tls.Config{
		InsecureSkipVerify: true,
	})
	assert.NoError(t, err, "Unable to dial")
	<-receivedServerNames
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestNotOKWithServerName(t *testing.T) {
	fdStart := countTCPFiles()
	conn, err := Dial("tcp", ADDR, true, nil)
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.Contains(t, err.Error(), CERTIFICATE_ERROR, "Wrong error on dial")
	}
	<-receivedServerNames
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestNotOKWithoutServerName(t *testing.T) {
	fdStart := countTCPFiles()
	conn, err := Dial("tcp", ADDR, true, &tls.Config{
		ServerName: "localhost",
	})
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.Contains(t, err.Error(), CERTIFICATE_ERROR, "Wrong error on dial")
	}
	serverName := <-receivedServerNames
	assert.Empty(t, serverName, "Unexpected ServerName on server")
	closeAndCountFDs(t, conn, err, fdStart)
}

func TestVariableTimeouts(t *testing.T) {
	// Timeouts can happen in different places, run a bunch of randomized trials
	// to try to cover all of them.
	fdStart := countTCPFiles()
	for i := 0; i < 500; i++ {
		doTestTimeout(t, time.Duration(rand.Intn(5000)+1)*time.Microsecond)
	}
	// Wait to give the sockets time to close
	time.Sleep(1 * time.Second)
	fdEnd := countTCPFiles()
	assert.Equal(t, fdStart, fdEnd, "Number of open files should be the same after test as before")
}

func doTestTimeout(t *testing.T, timeout time.Duration) {
	_, err := DialWithDialer(&net.Dialer{
		Timeout: timeout,
	}, "tcp", ADDR, false, nil)
	assert.Error(t, err, "There should have been a problem dialing", timeout)
	if err != nil {
		assert.True(t, err.(net.Error).Timeout(), "Dial error should be timeout", timeout)
	}
}

func TestDeadlineBeforeTimeout(t *testing.T) {
	fdStart := countTCPFiles()
	conn, err := DialWithDialer(&net.Dialer{
		Timeout:  500 * time.Second,
		Deadline: time.Now().Add(5 * time.Microsecond),
	}, "tcp", ADDR, false, nil)
	assert.Error(t, err, "There should have been a problem dialing")
	if err != nil {
		assert.True(t, err.(net.Error).Timeout(), "Dial error should be timeout")
	}
	closeAndCountFDs(t, conn, err, fdStart)
}

func closeAndCountFDs(t *testing.T, conn *tls.Conn, err error, fdStart int) {
	if err == nil {
		conn.Close()
	}
	fdEnd := countTCPFiles()
	assert.Equal(t, fdStart, fdEnd, "Number of open TCP files should be the same after test as before")
}

// see https://groups.google.com/forum/#!topic/golang-nuts/c0AnWXjzNIA
func countTCPFiles() int {
	out, err := exec.Command("lsof", "-p", fmt.Sprintf("%v", os.Getpid())).Output()
	if err != nil {
		log.Fatal(err)
	}
	return bytes.Count(out, []byte("TCP")) - 1
}
