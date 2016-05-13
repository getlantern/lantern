package fronted

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestCaching(t *testing.T) {
	dir, err := ioutil.TempDir("", "direct_test")
	if !assert.NoError(t, err, "Unable to create temp dir") {
		return
	}
	defer os.RemoveAll(dir)
	cacheFile := filepath.Join(dir, "cachefile")

	makeDirect := func() *direct {
		d := &direct{
			candidates:          make(chan *Masquerade, 1000),
			masquerades:         make(chan *Masquerade, 1000),
			maxAllowedCachedAge: 250 * time.Millisecond,
			maxCacheSize:        2,
			cacheSaveInterval:   50 * time.Millisecond,
			cacheFile:           cacheFile,
			cache:               make([]*Masquerade, 0),
			toCache:             make(chan *Masquerade, 1000),
		}
		go d.fillCache()
		return d
	}

	now := time.Now()
	ma := &Masquerade{Domain: "a", LastVetted: now}
	mb := &Masquerade{Domain: "b", LastVetted: now}
	mc := &Masquerade{Domain: "c", LastVetted: now}

	d := makeDirect()
	d.toCache <- ma
	d.toCache <- mb
	d.toCache <- mc

	readMasquerades := func() []*Masquerade {
		var result []*Masquerade
		for {
			select {
			case m := <-d.masquerades:
				result = append(result, m)
			default:
				return result
			}
		}
	}

	// Fill the cache
	time.Sleep(d.cacheSaveInterval * 2)
	d.closeCache()

	time.Sleep(50 * time.Millisecond)

	// Reopen cache file and make sure right data was in there
	d = makeDirect()
	d.prepopulateMasquerades()
	assert.Equal(t, []*Masquerade{mb, mc}, readMasquerades(), "Wrong stuff cached after reopening cache")
	d.closeCache()

	time.Sleep(d.maxAllowedCachedAge)
	d = makeDirect()
	d.prepopulateMasquerades()
	assert.Empty(t, readMasquerades(), "Cache should be empty after masquerades expire")
	d.closeCache()
}
