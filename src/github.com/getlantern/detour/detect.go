package detour

import (
	"bytes"
	"fmt"
	"net"
	"syscall"
)

type Detector struct {
	CheckConn  func(net.Conn) bool
	CheckResp  func([]byte) bool
	CheckError func(error) bool
}

var detectors = make(map[string]*Detector)

var iranRedirectIP = "10.10.34.34"

func init() {
	http403 := []byte("HTTP/1.1 403 Forbidden")
	iranIFrame := []byte(`<iframe src="http://10.10.34.34`)
	detectors["IR"] = &Detector{
		CheckConn: func(c net.Conn) bool {
			fmt.Println(c.RemoteAddr().String())
			if ra := c.RemoteAddr(); ra != nil {
				return ra.String() == iranRedirectIP
			}
			return false
		},
		CheckResp: func(b []byte) bool {
			return bytes.HasPrefix(b, http403) && bytes.Contains(b, iranIFrame)
		},
		CheckError: func(err error) bool {
			return false
		},
	}
}

var defaultDetector = Detector{
	func(net.Conn) bool { return false },
	func([]byte) bool { return false },
	func(err error) bool {
		if ne, ok := err.(net.Error); ok && ne.Timeout() {
			return true
		}
		if oe, ok := err.(*net.OpError); ok && (oe.Err == syscall.EPIPE || oe.Err == syscall.ECONNRESET) {
			return true
		}
		return false
	},
}

func detectorByCountry(country string) *Detector {
	d := detectors[country]
	if d == nil {
		return &defaultDetector
	}
	return &Detector{d.CheckConn, d.CheckResp, func(err error) bool {
		return defaultDetector.CheckError(err) || d.CheckError(err)
	},
	}
}
