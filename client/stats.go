package client

import (
	"net"
	"strings"

	"github.com/getlantern/bytecounting"

	"github.com/getlantern/flashlight/statreporter"
	"github.com/getlantern/flashlight/statserver"
)

// withStats wraps a connection with stat tracking logic, recording traffic
// under the Conn's RemoteAddr.
func withStats(conn net.Conn, err error) (net.Conn, error) {
	if err != nil {
		return conn, err
	}
	ip := strings.Split(conn.RemoteAddr().String(), ":")[0]
	return &bytecounting.Conn{
		Orig: conn,
		OnRead: func(bytes int64) {
			onBytesGotten(bytes)
			statserver.OnBytesReceived(ip, bytes)
		},
		OnWrite: func(bytes int64) {
			onBytesGotten(bytes)
			statserver.OnBytesSent(ip, bytes)
		},
	}, nil
}

func onBytesGotten(bytes int64) {
	dims := statreporter.CountryDim()
	dims.Increment("bytesGotten").Add(bytes)
}
