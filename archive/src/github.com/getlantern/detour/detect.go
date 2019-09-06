package detour

import (
	"bytes"
	"net"
)

// Detector is just a set of rules to check if a site is potentially blocked or not
type Detector struct {
	DNSPoisoned        func(net.Conn) bool
	TamperingSuspected func(error) bool
	FakeResponse       func([]byte) bool
}

var detectors = make(map[string]*Detector)

var iranRedirectAddr = "10.10.34.34:80"

func init() {
	http403 := []byte("HTTP/1.1 403 Forbidden")
	iranIFrame := []byte(`<iframe src="http://10.10.34.34`)
	// see tests and https://github.com/getlantern/lantern/issues/2099#issuecomment-78015418
	// for the facts behind detection rules for Iran
	detectors["IR"] = &Detector{
		DNSPoisoned: func(c net.Conn) bool {
			if ra := c.RemoteAddr(); ra != nil {
				return ra.String() == iranRedirectAddr
			}
			return false
		},
		FakeResponse: func(b []byte) bool {
			return bytes.HasPrefix(b, http403) && bytes.Contains(b, iranIFrame)
		},
		TamperingSuspected: func(err error) bool {
			return false
		},
	}
}

var defaultDetector = Detector{
	DNSPoisoned: func(net.Conn) bool { return false },
	TamperingSuspected: func(err error) bool {
		if ne, ok := err.(net.Error); ok && ne.Timeout() {
			return true
		}
		if _, ok := err.(*net.OpError); ok {
			// Let's be more aggressive on considering which errors are the
			// symptom of being blocked, because we can't reliably enumerate all
			// relevant errors. It's also a big plus if Lantern can help user to
			// bypass those various network errors, e.g., unresolvable host, route
			// errors, accessing IPv6 host from IPv4 network, etc.
			return true
		}
		return false
	},
	FakeResponse: func([]byte) bool { return false },
}

func detectorByCountry(country string) *Detector {
	d := detectors[country]
	if d == nil {
		return &defaultDetector
	}
	return &Detector{d.DNSPoisoned,
		func(err error) bool {
			return defaultDetector.TamperingSuspected(err) || d.TamperingSuspected(err)
		},
		d.FakeResponse,
	}
}
