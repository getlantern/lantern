package vpn

import (
	"io"
	"net"
	"time"

	"github.com/Jigsaw-Code/outline-sdk/transport"
)

const (
	tcpKeepAlivePeriod = 30 * time.Second
)

func copyOneWay(leftConn, rightConn transport.StreamConn) (int64, error) {
	n, err := io.Copy(leftConn, rightConn)
	// Send FIN to indicate EOF
	leftConn.CloseWrite()
	// Release reader resources
	rightConn.CloseRead()
	return n, err
}

// relay copies between left and right bidirectionally. Returns number of
// bytes copied from right to left, from left to right, and any error occurred.
// Relay allows for half-closed connections: if one side is done writing, it can
// still read all remaining data from its peer.
func relay(leftConn, rightConn transport.StreamConn) (int64, int64, error) {
	type res struct {
		N   int64
		Err error
	}
	ch := make(chan res)

	go func() {
		n, err := copyOneWay(rightConn, leftConn)
		ch <- res{n, err}
	}()

	n, err := copyOneWay(leftConn, rightConn)
	rs := <-ch

	if err == nil {
		err = rs.Err
	}
	return n, rs.N, err
}

// enableTCPKeepAlive configures TCP keep-alive on the provided connection
func enableTCPKeepAlive(conn net.Conn) {
	tcpConn, ok := conn.(*net.TCPConn)
	if !ok {
		log.Debug("Connection is not a TCP connection; cannot set keep-alives.")
		return
	}

	err := tcpConn.SetKeepAlive(true)
	if err != nil {
		log.Errorf("Failed to enable TCP keep-alives: %v", err)
		return
	}

	err = tcpConn.SetKeepAlivePeriod(tcpKeepAlivePeriod)
	if err != nil {
		log.Errorf("Failed to set TCP keep-alive period: %v", err)
	}
}
