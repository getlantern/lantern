package commonfilter

import (
	"errors"
	"net"
	"net/http"
	"strings"

	"github.com/getlantern/golog"
	"github.com/getlantern/http-proxy/utils"
)

var log = golog.LoggerFor("commonfilter")

type CommonFilter struct {
	errHandler utils.ErrorHandler
	next       http.Handler

	localIPs   []net.IP
	exceptions []string

	// Allow tests in localhost, because this filter blocks request to this address
	testingLocalhost bool
}

type optSetter func(f *CommonFilter) error

func SetException(addr string) optSetter {
	return func(f *CommonFilter) error {
		f.exceptions = append(f.exceptions, addr)
		return nil
	}
}

func New(next http.Handler, testingLocalhost bool, setters ...optSetter) (*CommonFilter, error) {
	f := &CommonFilter{
		next:             next,
		errHandler:       utils.DefaultHandler,
		testingLocalhost: testingLocalhost,
	}

	for _, s := range setters {
		if err := s(f); err != nil {
			return nil, err
		}
	}

	addrs, err := net.InterfaceAddrs()
	if err != nil {
		log.Errorf("Error enumerating local addresses: %v\n", err)
	}

	for _, a := range addrs {
		str := a.String()
		idx := strings.Index(str, "/")
		if idx != -1 {
			str = str[:idx]
		}
		ip := net.ParseIP(str)
		f.localIPs = append(f.localIPs, ip)
	}

	return f, nil
}

func (f *CommonFilter) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if !f.testingLocalhost && !f.isException(req.URL.Host) {
		reqAddr, err := net.ResolveTCPAddr("tcp", req.Host)

		// If there was an error resolving is probably because it wasn't an address
		// in the form localhost:port
		if err == nil {
			if reqAddr.IP.IsLoopback() {
				f.errHandler.ServeHTTP(w, req, err)
				return
			}
			for _, ip := range f.localIPs {
				if reqAddr.IP.Equal(ip) {
					f.errHandler.ServeHTTP(w, req, err)
					return
				}
			}

		}
	}

	if f.next == nil {
		f.errHandler.ServeHTTP(w, req, errors.New("Next handler is not defined (nil)"))
	} else {
		f.next.ServeHTTP(w, req)
	}
}

func (f *CommonFilter) isException(addr string) bool {
	for _, a := range f.exceptions {
		if a == addr {
			return true
		}
	}
	return false
}
