package config

import (
	"compress/gzip"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/http/httputil"
	"time"

	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/yamlconf"

	"code.google.com/p/go-uuid/uuid"
)

const (
	cloudConfigPollInterval = 1 * time.Minute
	etag                    = "X-Lantern-Etag"
	ifNoneMatch             = "X-Lantern-If-None-Match"
	userIDHeader            = "X-Lantern-User-Id"
	tokenHeader             = "X-Lantern-Pro-Token"
	chainedCloudConfigURL   = "http://config.getiantem.org/cloud.yaml.gz"

	// This is over HTTP because proxies do not forward X-Forwarded-For with HTTPS
	// and because we only support falling back to direct domain fronting through
	// the local proxy for HTTP.
	frontedCloudConfigURL = "http://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"
)

// fetcher periodically fetches the latest cloud configuration.
type fetcher struct {
	lastCloudConfigETag map[string]string
	user                UserConfig
	httpFetcher         util.HTTPFetcher
}

// UserConfig retrieves any custom user info for fetching the config.
type UserConfig interface {
	GetUserID() int
	GetToken() string
}

// NewFetcher creates a new configuration fetcher with the specified
// interface for obtaining the user ID and token if those are populated.
func NewFetcher(conf UserConfig, httpFetcher util.HTTPFetcher) Fetcher {
	return &fetcher{lastCloudConfigETag: map[string]string{}, user: conf, httpFetcher: httpFetcher}
}

func (cf *fetcher) pollForConfig(currentCfg yamlconf.Config, stickyConfig bool) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error) {
	log.Debugf("Polling for config")
	// By default, do nothing
	mutate = func(ycfg yamlconf.Config) error {
		// do nothing
		return nil
	}
	cfg := currentCfg.(*Config)
	waitTime = cf.cloudPollSleepTime()
	if cfg.CloudConfig == "" {
		log.Debugf("No cloud config URL!")
		// Config doesn't have a CloudConfig, just ignore
		return mutate, waitTime, nil
	}
	if stickyConfig {
		log.Debugf("Not downloading remote config with sticky config flag set")
		return mutate, waitTime, nil
	}

	if bytes, err := cf.fetchCloudConfig(chainedCloudConfigURL); err == nil {
		// bytes will be nil if the config is unchanged (not modified)
		if bytes != nil {
			//log.Debugf("Downloaded config:\n %v", string(bytes[:400]))
			mutate = func(ycfg yamlconf.Config) error {
				log.Debugf("Merging cloud configuration")
				cfg := ycfg.(*Config)

				err := cfg.updateFrom(bytes)
				if cfg.Client.ChainedServers != nil {
					log.Debugf("Adding %d chained servers", len(cfg.Client.ChainedServers))
					for _, s := range cfg.Client.ChainedServers {
						log.Debugf("Got chained server: %v", s.Addr)
					}
				}
				return err
			}
		}
	} else {
		log.Errorf("Could not fetch cloud config %v", err)
		return mutate, waitTime, err
	}
	return mutate, waitTime, nil
}

func (cf *fetcher) fetchCloudConfig(url string) ([]byte, error) {
	cb := "?" + uuid.New()
	nocache := url + cb
	req, err := http.NewRequest("GET", nocache, nil)
	if err != nil {
		return nil, fmt.Errorf("Unable to construct request for cloud config at %s: %s", nocache, err)
	}
	if cf.lastCloudConfigETag[url] != "" {
		// Don't bother fetching if unchanged
		req.Header.Set(ifNoneMatch, cf.lastCloudConfigETag[url])
	}

	req.Header.Set("Accept", "application/x-gzip")
	// Prevents intermediate nodes (domain-fronters) from caching the content
	req.Header.Set("Cache-Control", "no-cache")
	// Set the fronted URL to lookup the config in parallel using chained and domain fronted servers.
	req.Header.Set("Lantern-Fronted-URL", frontedCloudConfigURL+cb)

	id := cf.user.GetUserID()
	if id != 0 {
		req.Header.Set(userIDHeader, string(id))
	}
	tok := cf.user.GetToken()
	if tok != "" {
		req.Header.Set(tokenHeader, tok)
	}

	// make sure to close the connection after reading the Body
	// this prevents the occasional EOFs errors we're seeing with
	// successive requests
	req.Close = true

	resp, err := cf.httpFetcher.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Unable to fetch cloud config at %s: %s", url, err)
	}
	dump, err := httputil.DumpResponse(resp, false)
	if err != nil {
		log.Errorf("Could not dump response: %v", err)
	} else {
		log.Debugf("Response headers: \n%v", string(dump))
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Error closing response body: %v", err)
		}
	}()

	if resp.StatusCode == 304 {
		log.Debugf("Config unchanged in cloud")
		return nil, nil
	} else if resp.StatusCode != 200 {
		return nil, fmt.Errorf("Unexpected response status: %d", resp.StatusCode)
	}

	cf.lastCloudConfigETag[url] = resp.Header.Get(etag)
	gzReader, err := gzip.NewReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Unable to open gzip reader: %s", err)
	}
	log.Debugf("Fetched cloud config")
	return ioutil.ReadAll(gzReader)
}

// cloudPollSleepTime adds some randomization to our requests to make them
// less distinguishing on the network.
func (cf *fetcher) cloudPollSleepTime() time.Duration {
	return time.Duration((cloudConfigPollInterval.Nanoseconds() / 2) + rand.Int63n(cloudConfigPollInterval.Nanoseconds()))
}
