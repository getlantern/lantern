package forward

import (
	"net/http"
	"net/url"
)

// cloneURL provides update safe copy by avoiding shallow copying User field
func cloneURL(i *url.URL) *url.URL {
	out := *i
	if i.User != nil {
		out.User = &(*i.User)
	}
	return &out
}

// copyHeadersForForwarding will copy the headers but filter those that shouldn't be
// forwarded
func copyHeadersForForwarding(dst, src http.Header) {
	var extraHopByHopHeaders []string
	for k, vv := range src {
		switch k {
		// Skip hop-by-hop headers, ref section 13.5.1 of http://www.ietf.org/rfc/rfc2616.txt
		case "Connection":
			// section 14.10 of rfc2616
			// the slice is short typically, don't bother sort it to speed up lookup
			extraHopByHopHeaders = vv
		case "Keep-Alive":
		case "Proxy-Authenticate":
		case "Proxy-Authorization":
		case "TE":
		case "Trailers":
		case "Transfer-Encoding":
		case "Upgrade":
		default:
			if !contains(k, extraHopByHopHeaders) {
				for _, v := range vv {
					dst.Add(k, v)
				}
			}
		}
	}
}

func contains(k string, s []string) bool {
	for _, h := range s {
		if k == h {
			return true
		}
	}
	return false
}
