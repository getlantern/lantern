package interceptor

import (
	"net"
	"time"
)

type InterceptedConn struct {
	net.Conn
	id          string
	t           time.Time
	v           interface{}
	interceptor *Interceptor
	localConn   net.Conn
}
