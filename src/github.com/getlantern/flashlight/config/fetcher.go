package config

import (
	"compress/gzip"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"

	"github.com/getlantern/detour"

	"github.com/getlantern/flashlight/ops"
	"github.com/getlantern/flashlight/proxied"
)

const (
	etag         = "X-Lantern-Etag"
	ifNoneMatch  = "X-Lantern-If-None-Match"
	userIDHeader = "X-Lantern-User-Id"
	tokenHeader  = "X-Lantern-Pro-Token"
)

// Fetcher is an interface for fetching config updates.
type Fetcher interface {
	fetch() ([]byte, error)
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

// newFetcher creates a new configuration fetcher with the specified
// interface for obtaining the user ID and token if those are populated.
func newFetcher(conf UserConfig, rt http.RoundTripper, flags map[string]interface{}, fileName string) Fetcher {
	var stage bool
	if s, ok := flags["staging"].(bool); ok {
		stage = s
	}
	// This is over HTTP because proxies do not forward X-Forwarded-For with HTTPS
	// and because we only support falling back to direct domain fronting through
	// the local proxy for HTTP.
	var chained string
	var fronted string
	if stage {
		log.Debug("Configuring for staging")
		chained = "http://config-staging.getiantem.org/" + fileName
		fronted = "http://d33pfmbpauhmvd.cloudfront.net/" + fileName
	} else {
		log.Debugf("Not configuring for staging. Using flags: %v", flags)
		chained = "http://config.getiantem.org/" + fileName
		fronted = "http://d2wi0vwulmtn99.cloudfront.net/" + fileName

		if s, ok := flags["cloudconfig"].(string); ok {
			if len(s) > 0 {
				log.Debugf("Overridding chained URL from the command line '%v'", s)
				chained = s + fileName
			}
		}
		if s, ok := flags["frontedconfig"].(string); ok {
			if len(s) > 0 {
				log.Debugf("Overridding fronted URL from the command line '%v'", s)
				fronted = s + fileName
			}
		}
	}

	log.Debugf("Will poll for config at %v (%v)", chained, fronted)

	// Force detour to whitelist chained domain
	u, err := url.Parse(chained)
	if err != nil {
		log.Fatalf("Unable to parse chained cloud config URL: %v", err)
	}
	detour.ForceWhitelist(u.Host)

	return &fetcher{
		lastCloudConfigETag: map[string]string{},
		user:                conf,
		rt:                  rt,
		chainedURL:          chained,
		frontedURL:          fronted,
	}
}

func (cf *fetcher) fetch() ([]byte, error) {
	defer ops.Begin("fetch_config").End()
	log.Debugf("Fetching cloud config from %v (%v)", cf.chainedURL, cf.frontedURL)

	url := cf.chainedURL
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("Unable to construct request for cloud config at %s: %s", url, err)
	}
	if cf.lastCloudConfigETag[url] != "" {
		// Don't bother fetching if unchanged
		req.Header.Set(ifNoneMatch, cf.lastCloudConfigETag[url])
	}

	req.Header.Set("Accept", "application/x-gzip")
	// Prevents intermediate nodes (domain-fronters) from caching the content
	req.Header.Set("Cache-Control", "no-cache")
	// Set the fronted URL to lookup the config in parallel using chained and domain fronted servers.
	proxied.PrepareForFronting(req, cf.frontedURL)

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
		log.Debug("Config unchanged in cloud")
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
