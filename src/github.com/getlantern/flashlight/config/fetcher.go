package config

import (
	"compress/gzip"
	"fmt"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/http/httputil"
	"strconv"
	"time"

	"code.google.com/p/go-uuid/uuid"

	"github.com/getlantern/yamlconf"

	"github.com/getlantern/flashlight/ops"
	"github.com/getlantern/flashlight/proxied"
)

const (
	etag         = "X-Lantern-Etag"
	ifNoneMatch  = "X-Lantern-If-None-Match"
	userIDHeader = "X-Lantern-User-Id"
	tokenHeader  = "X-Lantern-Pro-Token"

	defaultChainedCloudConfigURL = "http://config.getiantem.org/cloud.yaml.gz"

	// This is over HTTP because proxies do not forward X-Forwarded-For with HTTPS
	// and because we only support falling back to direct domain fronting through
	// the local proxy for HTTP.
	defaultFrontedCloudConfigURL = "http://d2wi0vwulmtn99.cloudfront.net/cloud.yaml.gz"
)

var (
	// CloudConfigPollInterval is the period to wait befween checks for new
	// global configuration settings.
	CloudConfigPollInterval = 1 * time.Minute
)

// Fetcher is an interface for fetching config updates.
type Fetcher interface {
	pollForConfig(ycfg yamlconf.Config, sticky bool) (mutate func(yamlconf.Config) error, waitTime time.Duration, err error)
}

// fetcher periodically fetches the latest cloud configuration.
type fetcher struct {
	lastCloudConfigETag map[string]string
	user                UserConfig
	rt                  http.RoundTripper
	chainedURL          string
	frontedURL          string
}

// UserConfig retrieves any custom user info for fetching the config.
type UserConfig interface {
	GetUserID() int64
	GetToken() string
}

// NewFetcher creates a new configuration fetcher with the specified
// interface for obtaining the user ID and token if those are populated.
func NewFetcher(conf UserConfig, rt http.RoundTripper, flags map[string]interface{}) Fetcher {
	var stage bool
	if s, ok := flags["staging"].(bool); ok {
		stage = s
	}
	var chained string = defaultChainedCloudConfigURL
	var fronted string = defaultFrontedCloudConfigURL
	if stage {
		log.Debug("Configuring for staging")
		chained = "http://config-staging.getiantem.org/cloud.yaml.gz"
		fronted = "http://d33pfmbpauhmvd.cloudfront.net/cloud.yaml.gz"
	} else {
		log.Debugf("Not configuring for staging. Using flags: %v", flags)

		if s, ok := flags["cloudconfig"].(string); ok {
			if len(s) > 0 {
				log.Debugf("Overridding chained URL from the command line '%v'", s)
				chained = s
			}
		}
		if s, ok := flags["frontedconfig"].(string); ok {
			if len(s) > 0 {
				log.Debugf("Overridding fronted URL from the command line '%v'", s)
				fronted = s
			}
		}
	}

	return &fetcher{
		lastCloudConfigETag: map[string]string{},
		user:                conf,
		rt:                  rt,
		chainedURL:          chained,
		frontedURL:          fronted,
	}
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
	if stickyConfig {
		log.Debugf("Not downloading remote config with sticky config flag set")
		return mutate, waitTime, nil
	}

	if bytes, err := cf.fetchCloudConfig(cfg); err != nil {
		log.Errorf("Could not fetch cloud config %v", err)
		return mutate, waitTime, err
	} else if bytes != nil {
		// bytes will be nil if the config is unchanged (not modified)
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
	} else {
		log.Debugf("Bytes are nil - config not modified.")
	}
	return mutate, waitTime, nil
}

func (cf *fetcher) fetchCloudConfig(cfg *Config) ([]byte, error) {
	defer ops.Enter("fetch_config").Exit()
	log.Debugf("Fetching cloud config from %v (%v)", cf.chainedURL, cf.frontedURL)

	url := cf.chainedURL
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
	proxied.PrepareForFronting(req, cf.frontedURL+cb)

	id := cf.user.GetUserID()
	if id != 0 {
		strID := strconv.FormatInt(id, 10)
		req.Header.Set(userIDHeader, strID)
	}
	tok := cf.user.GetToken()
	if tok != "" {
		req.Header.Set(tokenHeader, tok)
	}

	// make sure to close the connection after reading the Body
	// this prevents the occasional EOFs errors we're seeing with
	// successive requests
	req.Close = true

	resp, err := cf.rt.RoundTrip(req)
	if err != nil {
		return nil, fmt.Errorf("Unable to fetch cloud config at %s: %s", url, err)
	}
	dump, dumperr := httputil.DumpResponse(resp, false)
	if dumperr != nil {
		log.Errorf("Could not dump response: %v", dumperr)
	} else {
		log.Debugf("Response headers: \n%v", string(dump))
	}
	defer func() {
		if closeerr := resp.Body.Close(); closeerr != nil {
			log.Errorf("Error closing response body: %v", closeerr)
		}
	}()

	if resp.StatusCode == 304 {
		log.Debugf("Config unchanged in cloud")
		return nil, nil
	} else if resp.StatusCode != 200 {
		if dumperr != nil {
			return nil, fmt.Errorf("Bad config response code: %v", resp.StatusCode)
		}
		return nil, fmt.Errorf("Bad config resp:\n%v", string(dump))
	}

	cf.lastCloudConfigETag[url] = resp.Header.Get(etag)
	gzReader, err := gzip.NewReader(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("Unable to open gzip reader: %s", err)
	}

	defer func() {
		if err := gzReader.Close(); err != nil {
			log.Errorf("Unable to close gzip reader: %v", err)
		}
	}()

	log.Debugf("Fetched cloud config")
	return ioutil.ReadAll(gzReader)
}

// cloudPollSleepTime adds some randomization to our requests to make them
// less distinguishing on the network.
func (cf *fetcher) cloudPollSleepTime() time.Duration {
	return time.Duration((CloudConfigPollInterval.Nanoseconds() / 2) + rand.Int63n(CloudConfigPollInterval.Nanoseconds()))
}
