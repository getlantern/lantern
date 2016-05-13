package fronted

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"time"
)

var (
	maxAllowedCachedAge = 24 * time.Hour
	maxCacheSize        = 1000
	cacheSaveInterval   = 5 * time.Second

	// Nil value indicates end of cache filling
	fillSentinel *Masquerade = nil
)

func (d *direct) initCaching() int {
	prevetted := d.prepopulateMasquerades()
	go d.fillCache()
	return prevetted
}

func (d *direct) prepopulateMasquerades() int {
	file, err := os.Open(d.cacheFile)
	if err == nil {
		log.Debugf("Attempting to prepopulate masquerades from cache")
		defer file.Close()
		var masquerades []*Masquerade
		err := json.NewDecoder(file).Decode(&masquerades)
		if err != nil {
			log.Errorf("Error prepopulating cached masquerades: %v", err)
			return 0
		}

		log.Debugf("Cache contained %d masquerades", len(masquerades))
		now := time.Now()
		for _, m := range masquerades {
			if now.Sub(m.LastVetted) < maxAllowedCachedAge {
				select {
				case d.masquerades <- m:
					// submitted
					d.cache = append(d.cache, m)
				default:
					// channel full, that's okay
				}
			}
		}
	}

	return len(d.cache)
}

func (d *direct) fillCache() {
	saveTimer := time.NewTimer(cacheSaveInterval)
	cacheChanged := false
	for {
		select {
		case m := <-d.toCache:
			if m == fillSentinel {
				log.Debug("Cache closed, stop filling")
				return
			}
			log.Debugf("Caching vetted masquerade for %v (%v)", m.Domain, m.IpAddress)
			d.cache = append(d.cache, m)
			cacheChanged = true
		case <-saveTimer.C:
			if !cacheChanged {
				continue
			}
			log.Debug("Saving updated masquerade cache")
			// Truncate cache to max length if necessary
			if len(d.cache) > maxCacheSize {
				truncated := make([]*Masquerade, maxCacheSize)
				copy(truncated, d.cache[len(d.cache)-maxCacheSize:])
				d.cache = truncated
			}
			b, err := json.Marshal(d.cache)
			if err != nil {
				log.Errorf("Unable to marshal cache to JSON: %v", err)
				break
			}
			err = ioutil.WriteFile(d.cacheFile, b, 0644)
			if err != nil {
				log.Errorf("Unable to save cache to disk: %v", err)
			}
			cacheChanged = false
			saveTimer.Reset(cacheSaveInterval)
		}
	}
}

// CloseCache closes any existing file cache.
func CloseCache() {
	_existing, ok := _instance.Get(0)
	log.Debug("Got existing instance")
	if ok && _existing != nil {
		existing := _existing.(*direct)
		log.Debug("Closing cache from existing instance")
		existing.closeCache()
	}
}

func (d *direct) closeCache() {
	d.toCache <- fillSentinel
}
