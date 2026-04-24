package lanterncore

import (
	"testing"

	"github.com/getlantern/radiance/vpn"
)

func TestNormalizeAutoTag(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"empty tag (Smart from UI) normalizes to auto-select", "", vpn.AutoSelectTag},
		{"named tag passes through", "samizdat-out-samizdat-free-oci-v2-4b2a5569", "samizdat-out-samizdat-free-oci-v2-4b2a5569"},
		{"explicit auto tag passes through", vpn.AutoSelectTag, vpn.AutoSelectTag},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := normalizeAutoTag(tc.in); got != tc.want {
				t.Errorf("normalizeAutoTag(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}
