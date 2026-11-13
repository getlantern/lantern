package lanterncore

import (
	"strings"
	"testing"

	"github.com/sagernet/sing-box/adapter"
	C "github.com/sagernet/sing-box/constant"
	O "github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/route/rule"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNormalizeSplitTunnelWebsite(t *testing.T) {
	lc := &LanternCore{}
	for input, want := range map[string]string{
		" Example.COM. ": "example.com", "api.example.co.uk": "api.example.co.uk",
		"example.international": "example.international", "*.IR": ".ir", "*.Example.COM.": ".example.com",
		"https://api.example.com:443/path?q=1#x": "api.example.com",
		"bücher.de":                              "xn--bcher-kva.de", "例子.测试": "xn--fsqu00a.xn--0zwm56d",
		"ＦＯＯ.com": "foo.com", "*。Example。com": ".example.com",
	} {
		t.Run(input, func(t *testing.T) {
			got, err := lc.NormalizeSplitTunnelWebsite(input)
			require.NoError(t, err)
			assert.Equal(t, want, got)
			canonical, err := splitTunnelDomain(got)
			require.NoError(t, err)
			assert.Equal(t, got, canonical)
		})
	}
	for _, input := range []string{
		"", "*", "*ir", "foo.*.com", "exam*ple.com", ".example.com", "example..com", "example.com..", "-x.com", "x-.com", "a_b.com",
		"ir", "127.0.0.1", "127.000.0.1", "*.127.0.0.1", "https://127.0.0.1", "[::1]", "https://[::1]/", "999.999.999.999",
		"https://user:pass@example.com", "ftp://example.com", "example.com:bad", "example.com:70000", "a b.com", "foo\\bar.com",
		"example.com/path", "example.com:443", "https://*.example.com/a", "https://example.com:0", "https://example.com:65536",
		"。example.com", "．example.com", "｡example.com",
		strings.Repeat("x", 64) + ".com", strings.Repeat("longlabel.", 30) + "com",
	} {
		t.Run(input, func(t *testing.T) { _, err := lc.NormalizeSplitTunnelWebsite(input); require.Error(t, err) })
	}
}

func TestSplitTunnelWebsiteBoundaries(t *testing.T) {
	for _, tt := range []struct {
		input string
		host  string
		match bool
	}{
		{"example.com", "example.com", true},
		{"example.com", "a.example.com", true},
		{"example.com", "badexample.com", false},
		{"*.example.com", "example.com", false},
		{"*.example.com", "a.example.com", true},
		{"*.example.com", "badexample.com", false},
		{"api.example.co.uk", "example.co.uk", false},
		{"api.example.co.uk", "api.example.co.uk", true},
		{"*.ir", "bank.ir", true},
		{"*.ir", "ir", false},
	} {
		t.Run(tt.input+"/"+tt.host, func(t *testing.T) {
			suffix, err := splitTunnelDomain(tt.input)
			require.NoError(t, err)
			matcher, err := rule.NewHeadlessRule(t.Context(), O.HeadlessRule{
				Type: C.RuleTypeDefault, DefaultOptions: O.DefaultHeadlessRule{DomainSuffix: []string{suffix}},
			})
			require.NoError(t, err)
			assert.Equal(t, tt.match, matcher.Match(&adapter.InboundContext{Domain: tt.host}))
		})
	}
}
