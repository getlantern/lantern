package proxiedsites

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestConfigureAndPAC(t *testing.T) {
	expectedDeltaA := &Delta{
		Additions: []string{"A", "B", "D"},
	}
	expectedDeltaB := &Delta{
		Additions: []string{"E"},
		Deletions: []string{"B", "D"},
	}

	delta := Configure(&Config{
		Cloud: []string{"A", "B", "C"},
		Delta: &Delta{
			Additions: []string{"D"},
			Deletions: []string{"C"},
		},
	})
	assert.Equal(t, expectedDeltaA, delta)

	delta = Configure(&Config{
		Cloud: []string{"A", "B", "C"},
		Delta: &Delta{
			Additions: []string{"E"},
			Deletions: []string{"B", "C"},
		},
	})
	assert.Equal(t, expectedDeltaB, delta)
}

func TestDeltaMerge(t *testing.T) {
	d := &Delta{
		Additions: []string{},
		Deletions: []string{},
	}

	// Initial merge
	d.Merge(&Delta{
		Additions: []string{"A"},
		Deletions: []string{"K"},
	})
	assert.Equal(t, &Delta{
		Additions: []string{"A"},
		Deletions: []string{"K"},
	}, d)

	// Totally New Elements
	d.Merge(&Delta{
		Additions: []string{"B"},
		Deletions: []string{"L"},
	})
	assert.Equal(t, &Delta{
		Additions: []string{"A", "B"},
		Deletions: []string{"K", "L"},
	}, d)

	// Flip flop
	d.Merge(&Delta{
		Additions: []string{"K"},
		Deletions: []string{"A"},
	})
	assert.Equal(t, &Delta{
		Additions: []string{"B", "K"},
		Deletions: []string{"A", "L"},
	}, d)
}

func TestEquals(t *testing.T) {
	a := csFor(&Config{
		Cloud: []string{"A", "B", "C"},
		Delta: &Delta{
			Additions: []string{"D"},
			Deletions: []string{"C"},
		},
	})
	b := csFor(&Config{
		Cloud: []string{"A", "B"},
		Delta: &Delta{
			Additions: []string{"D"},
			Deletions: []string{"C"},
		},
	})
	c := csFor(&Config{
		Cloud: []string{"A", "B", "C"},
		Delta: &Delta{
			Additions: []string{"D", "E"},
			Deletions: []string{"C"},
		},
	})
	d := csFor(&Config{
		Cloud: []string{"A", "B", "C"},
		Delta: &Delta{
			Additions: []string{"D"},
			Deletions: []string{"C", "E"},
		},
	})

	assert.True(t, a.equals(a), "a should equal itself")
	assert.False(t, a.equals(b), "a should not equal b")
	assert.False(t, a.equals(c), "a should not equal c")
	assert.False(t, a.equals(d), "a should not equal d")
}

func csFor(cfg *Config) *configsets {
	return cfg.toCS()
}

const expectedPACFile = `var proxyDomains = new Array();
var i=0;


proxyDomains[i++] = "A";
proxyDomains[i++] = "B";
proxyDomains[i++] = "D";

for(i in proxyDomains) {
    proxyDomains[i] = proxyDomains[i].split(/\./).join("\\.");
}

var proxyDomainsRegx = new RegExp("(" + proxyDomains.join("|") + ")$", "i");

function FindProxyForURL(url, host) {
    if( host == "localhost" ||
        host == "127.0.0.1") {
        return "DIRECT";
    }

    if (proxyDomainsRegx.exec(host)) {
        return "PROXY 127.0.0.1:8789; DIRECT";
    }

    return "DIRECT";
}
`
