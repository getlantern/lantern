package fronted

import (
	"encoding/json"
	"io/ioutil"
	"os"
	"time"
)

var (
	// Nil value indicates end of cache filling
	fillSentinel *Masquerade = nil
)

func (d *direct) initCaching(cacheFile string) int {
	cache := d.prepopulateMasquerades(cacheFile)
	prevetted := len(cache)
	go d.fillCache(cache, cacheFile)
	return prevetted
}

func (d *direct) prepopulateMasquerades(cacheFile string) []*Masquerade {
	var cache []*Masquerade
	file, err := os.Open(cacheFile)
	if err == nil {
		log.Debugf("Attempting to prepopulate masquerades from cache")
		defer file.Close()
		var masquerades []*Masquerade
		err := json.NewDecoder(file).Decode(&masquerades)
		if err != nil {
			log.Errorf("Error prepopulating cached masquerades: %v", err)
			return cache
		}

		log.Debugf("Cache contained %d masquerades", len(masquerades))
		now := time.Now()
		for _, m := range masquerades {
			if now.Sub(m.LastVetted) < d.maxAllowedCachedAge {
				select {
				case d.masquerades <- m:
					// submitted
					cache = append(cache, m)
				default:
					// channel full, that's okay
				}
			}
		}
	}

	return cache
}

func (d *direct) fillCache(cache []*Masquerade, cacheFile string) {
	saveTimer := time.NewTimer(d.cacheSaveInterval)
	cacheChanged := false
	for {
		select {
		case m := <-d.toCache:
			if m == fillSentinel {
				log.Debug("Cache closed, stop filling")
				return
			}
			log.Debugf("Caching vetted masquerade for %v (%v)", m.Domain, m.IpAddress)
			cache = append(cache, m)
			cacheChanged = true
		case <-saveTimer.C:
			if !cacheChanged {
				continue
			}
			log.Debug("Saving updated masquerade cache")
			// Truncate cache to max length if necessary
			if len(cache) > d.maxCacheSize {
				truncated := make([]*Masquerade, d.maxCacheSize)
				copy(truncated, cache[len(cache)-d.maxCacheSize:])
				cache = truncated
			}
			b, err := json.Marshal(cache)
			if err != nil {
				log.Errorf("Unable to marshal cache to JSON: %v", err)
				break
			}
			err = ioutil.WriteFile(cacheFile, b, 0644)
			if err != nil {
				log.Errorf("Unable to save cache to disk: %v", err)
			}
			cacheChanged = false
			saveTimer.Reset(d.cacheSaveInterval)
		}
	}
}

// CloseCache closes any existing file cache.
func CloseCache() {
	_existing, ok := _instance.Get(0)
	if ok && _existing != nil {
		existing := _existing.(*direct)
		log.Debug("Closing cache from existing instance")
		existing.closeCache()
	}
}

func (d *direct) closeCache() {
	d.toCache <- fillSentinel
}
