package flashlight

import (
	"fmt"
	"strings"
	"time"

	"github.com/getlantern/flashlight/geolookup"
)

const (
	// the Feed endpoint where recent content is published to
	// mostly just a compendium of RSS feeds
	feedEndpoint = `https://feeds.getiantem.org/%s/feed.json`
)

// GetFeedURL returns the URL to use for looking up the feed by looking up
// the users country before defaulting to the specified backup locale if the
// country can't be determined.
func GetFeedURL(backupLocale string) string {
	var locale = backupLocale
	country := geolookup.GetCountry(time.Duration(10) * time.Second)
	if country == "" {
		// This means the country lookup failed, so just use whatever the default is.
		log.Debug("Could not lookup country")
		locale = backupLocale
	} else if strings.EqualFold("ir", country) {
		locale = "fa_IR"
	}
	url := fmt.Sprintf(feedEndpoint, locale)
	log.Debugf("Returning feed URL: %v", url)
	return url
}
