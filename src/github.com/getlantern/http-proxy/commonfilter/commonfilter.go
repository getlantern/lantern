package commonfilter

import (
	"net"
	"net/http"
	"strings"

	"github.com/getlantern/golog"

	"github.com/getlantern/http-proxy/filters"
)

var log = golog.LoggerFor("commonfilter")

type Options struct {
	AllowLocalhost bool
	Exceptions     []string
}

type commonFilter struct {
	*Options
	localIPs []net.IP
}

func New(opts *Options) filters.Filter {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		log.Errorf("Error enumerating local addresses: %v\n", err)
	}

	localIPs := make([]net.IP, 0, len(addrs))
	for _, a := range addrs {
		str := a.String()
		idx := strings.Index(str, "/")
		if idx != -1 {
			str = str[:idx]
		}
		ip := net.ParseIP(str)
		localIPs = append(localIPs, ip)
	}

	return &commonFilter{opts, localIPs}
}

func (f *commonFilter) Apply(w http.ResponseWriter, req *http.Request, next filters.Next) error {
	if !f.AllowLocalhost && !f.isException(req.URL.Host) {
		reqAddr, err := net.ResolveTCPAddr("tcp", req.Host)

		// If there was an error resolving is probably because it wasn't an address
		// in the form localhost:port
		if err == nil {
			if reqAddr.IP.IsLoopback() {
				return filters.Fail("%v requested loopback address %v (%v)", req.RemoteAddr, req.Host, reqAddr)
			}
			for _, ip := range f.localIPs {
				if reqAddr.IP.Equal(ip) {
					return filters.Fail("%v requested local address %v (%v)", req.RemoteAddr, req.Host, reqAddr)
				}
			}

		}
	}

	return next()
}

func (f *commonFilter) isException(addr string) bool {
	for _, a := range f.Exceptions {
		if a == addr {
			return true
		}
	}
	return false
}
