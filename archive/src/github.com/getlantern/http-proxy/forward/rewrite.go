package forward

import (
	"net"
	"net/http"
	"strings"
)

const (
	XForwardedProto  = "X-Forwarded-Proto"
	XForwardedFor    = "X-Forwarded-For"
	XForwardedHost   = "X-Forwarded-Host"
	XForwardedServer = "X-Forwarded-Server"
	ContentLength    = "Content-Length"
)

// Rewriter is responsible for removing hop-by-hop headers and setting forwarding headers
type HeaderRewriter struct {
	TrustForwardHeader bool
	Hostname           string
}

func (rw *HeaderRewriter) Rewrite(req *http.Request) {
	if clientIP, _, err := net.SplitHostPort(req.RemoteAddr); err == nil {
		if rw.TrustForwardHeader {
			if prior, ok := req.Header[XForwardedFor]; ok {
				clientIP = strings.Join(prior, ", ") + ", " + clientIP
			}
		}
		req.Header.Set(XForwardedFor, clientIP)
	}

	// In principle we don't want to add the Proto and Host headers
	/*
		if xfp := req.Header.Get(XForwardedProto); xfp != "" && rw.TrustForwardHeader {
			req.Header.Set(XForwardedProto, xfp)
		} else if req.TLS != nil {
			req.Header.Set(XForwardedProto, "https")
		} else {
			req.Header.Set(XForwardedProto, "http")
		}

		if xfh := req.Header.Get(XForwardedHost); xfh != "" && rw.TrustForwardHeader {
			req.Header.Set(XForwardedHost, xfh)
		} else if req.Host != "" {
			req.Header.Set(XForwardedHost, req.Host)
		}
	*/

	if rw.Hostname != "" {
		req.Header.Set(XForwardedServer, rw.Hostname)
	}
}
