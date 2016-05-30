package listeners

import (
	"net"
	"net/http"
	"time"

	"github.com/getlantern/measured"
)

// Wrapped stateAwareMeasuredListener that genrates the wrapped wrapMeasuredConn
type stateAwareMeasuredListener struct {
	measured.MeasuredListener
}

func NewMeasuredListener(l net.Listener, reportInterval time.Duration, m *measured.Measured) net.Listener {
	return &stateAwareMeasuredListener{
		MeasuredListener: *m.Listener(l, reportInterval),
	}
}

func (l *stateAwareMeasuredListener) Accept() (c net.Conn, err error) {
	c, err = l.MeasuredListener.Accept()
	if err != nil {
		return nil, err
	}
	sac, _ := c.(*measured.Conn).Conn.(WrapConnEmbeddable)
	return &wrapMeasuredConn{
		WrapConnEmbeddable: sac,
		Conn:               c.(*measured.Conn),
	}, err
}

// Wrapped MeasuredConn that supports OnState
type wrapMeasuredConn struct {
	WrapConnEmbeddable
	*measured.Conn
}

func (c *wrapMeasuredConn) OnState(s http.ConnState) {
	if c.WrapConnEmbeddable != nil {
		c.WrapConnEmbeddable.OnState(s)
	}
}

// Responds to the "measured" message type
func (c *wrapMeasuredConn) ControlMessage(msgType string, data interface{}) {
	if msgType == "measured" {
		c.Conn.ID = data.(string)
	}

	// Pass it down too, just in case other wrapper does something with
	if c.WrapConnEmbeddable != nil {
		c.WrapConnEmbeddable.ControlMessage(msgType, data)
	}
}
