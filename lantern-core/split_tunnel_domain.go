package lanterncore

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
	"unicode"

	"golang.org/x/net/idna"
)

var splitTunnelDomainSeparators = strings.NewReplacer("\u3002", ".", "\uff0e", ".", "\uff61", ".")

// NormalizeSplitTunnelWebsite returns an ASCII domain suffix; a leading dot excludes the apex.
func (lc *LanternCore) NormalizeSplitTunnelWebsite(input string) (string, error) {
	input = splitTunnelDomainSeparators.Replace(input)
	if strings.HasPrefix(strings.TrimSpace(input), ".") {
		return "", fmt.Errorf("use *. for a website wildcard")
	}
	return splitTunnelDomain(input)
}

func splitTunnelDomain(input string) (string, error) {
	invalid := func() (string, error) { return "", fmt.Errorf("invalid split-tunnel website: %q", input) }
	host := splitTunnelDomainSeparators.Replace(strings.TrimSpace(input))
	if host == "" || strings.IndexFunc(host, unicode.IsSpace) >= 0 {
		return invalid()
	}
	wildcard := strings.HasPrefix(host, "*.") || strings.HasPrefix(host, ".")
	if strings.Contains(host, "://") {
		u, err := url.Parse(host)
		if err != nil || (!strings.EqualFold(u.Scheme, "https") && !strings.EqualFold(u.Scheme, "http")) || u.User != nil || u.Hostname() == "" {
			return invalid()
		}
		if port := u.Port(); port != "" {
			n, err := strconv.Atoi(port)
			if err != nil || n < 1 || n > 65535 {
				return invalid()
			}
		}
		host = u.Hostname()
		wildcard = false
	}
	if wildcard {
		host = strings.TrimPrefix(strings.TrimPrefix(host, "*"), ".")
	}
	if strings.ContainsAny(host, "*:/?#@\\[]%") {
		return invalid()
	}
	host, err := idna.Lookup.ToASCII(host)
	if err != nil {
		return invalid()
	}
	host = strings.ToLower(strings.TrimSuffix(host, "."))
	if host == "" || len(host) > 253 || net.ParseIP(host) != nil {
		return invalid()
	}
	labels := strings.Split(host, ".")
	if len(labels) < 2 && !wildcard {
		return invalid()
	}
	numeric := true
	for _, label := range labels {
		if len(label) == 0 || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return invalid()
		}
		for _, c := range label {
			if (c < 'a' || c > 'z') && (c < '0' || c > '9') && c != '-' {
				return invalid()
			}
			if c < '0' || c > '9' {
				numeric = false
			}
		}
	}
	if numeric {
		return invalid()
	}
	if wildcard {
		return "." + host, nil
	}
	return host, nil
}
