package feed

import (
	"fmt"
	"strings"
	"time"

	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/golog"
)

const (
	// the Feed endpoint where recent content is published to
	// mostly just a compendium of RSS feeds
	feedEndpoint = "https://feeds.getiantem.org/%s/feed.json"
	en           = "en_US"
)

var (
	log            = golog.LoggerFor("feed")
	EnFeedEndpoint = fmt.Sprintf(feedEndpoint, en)
)

// GetFeedURL returns the URL to use for looking up the feed by looking up
// the users country before defaulting to the specified default locale if the
// country can't be determined.
func GetFeedURL(defaultLocale string) string {
	locale := determineLocale(defaultLocale)
	url := fmt.Sprintf(feedEndpoint, locale)
	log.Debugf("Returning feed URL: %v", url)
	return url
}

func determineLocale(defaultLocale string) string {
	// As of this writing the only countries we know of where we want a unique
	// feed for the country that's different from the dominantly installed
	// language are Iran and Malaysia. In both countries english is the most
	// common language on people's machines. We can therefor optimize a little
	// bit here and skip the country lookup if the locale is not en_US.
	if !strings.EqualFold(en, defaultLocale) {
		return defaultLocale
	}
	country := geolookup.GetCountry(time.Duration(10) * time.Second)
	if country == "" {
		// This means the country lookup failed, so just use whatever the default is.
		log.Debug("Could not lookup country")
		return defaultLocale
	} else if strings.EqualFold("ir", country) {
		return "fa_IR"
	}
	return defaultLocale
}
