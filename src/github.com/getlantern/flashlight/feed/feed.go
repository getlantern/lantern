package feed

import (
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/golog"
)

const (
	// the Feed endpoint where recent content is published to
	// mostly just a compendium of RSS feeds
	defaultFeedEndpoint = "https://feeds.getiantem.org/%s/feed.json"
	fallbackEndpoint    = "https://feeds.getiantem.org/en_US/feed.json"
	en                  = "en_US"
)

var (
	feed *Feed

	_httpClient     *http.Client
	httpClientMutex sync.Mutex
	log             = golog.LoggerFor("feed")
)

// Feed contains the data we get back
// from the public feed
type Feed struct {
	Feeds   map[string]*Source   `json:"feeds"`
	Entries FeedItems            `json:"entries"`
	Items   map[string]FeedItems `json:"-"`
	Sorted  []string             `json:"sorted_feeds"`
}

// Source represents a feed authority,
// a place where content is fetched from
// e.g. BBC, NYT, Reddit, etc.
type Source struct {
	FeedUrl        string `json:"feedUrl"`
	Title          string `json:"title"`
	Url            string `json:"link"`
	ExcludeFromAll bool   `json:"excludeFromAll"`
	Entries        []int  `json:"entries"`
}

type FeedItem struct {
	Title       string                 `json:"title"`
	Link        string                 `json:"link"`
	Image       string                 `json:"image"`
	Meta        map[string]interface{} `json:"meta,omitempty"`
	Content     string                 `json:"contentSnippetText"`
	Source      string                 `json:"source"`
	Description string                 `json:"-"`
}

type FeedItems []*FeedItem

type FeedProvider interface {
	// AddSource: called for each new feed source
	AddSource(string)
}

type FeedRetriever interface {
	// AddFeed: used to add a new entry to a given feed
	AddFeed(string, string, string, string)
}

// FeedByName checks the previously created feed for an
// entry with the given source name
func FeedByName(name string, retriever FeedRetriever) {
	if feed != nil && feed.Items != nil {
		if items, exists := feed.Items[name]; exists {
			for _, i := range items {
				retriever.AddFeed(i.Title, i.Description,
					i.Image, i.Link)
			}
		}
	}
}

// NumFeedEntries just returns the total number of entries
// across all feeds
func NumFeedEntries() int {
	count := len(feed.Entries)
	log.Debugf("Number of feed entries: %d", count)
	return count
}

// Returns the latest feed or nil if it doesn't exist
func CurrentFeed() *Feed {
	return feed
}

// GetFeed creates an http.Client and fetches the latest
// Lantern public feed for displaying on the home screen.
func GetFeed(locale string, allStr string, shouldProxy bool, provider FeedProvider) {
	doGetFeed(defaultFeedEndpoint, locale, shouldProxy, allStr, provider)
}

// handleError logs the given error message and sets the current feed to nil
func handleError(err error) {
	log.Error(err)
	feed = nil
}

// doRequest creates an HTTP request for the given feedURL and returns an HTTP
// response. If an invalid status code is returned, it could be
// because there is no feed available for the given locale so we
// default to the given fallback url.
func doRequest(httpClient *http.Client, feedURL string) (*http.Response, error) {
	var err error
	var req *http.Request
	var res *http.Response

	if req, err = http.NewRequest("GET", feedURL, nil); err != nil {
		handleError(fmt.Errorf("Error fetching feed: %v", err))
		return nil, err
	}

	// ask for gzipped feed content
	req.Header.Add("Accept-Encoding", "gzip")

	if res, err = httpClient.Do(req); err != nil {
		handleError(fmt.Errorf("Error fetching feed: %v", err))
		return nil, err
	}

	if res.StatusCode != http.StatusOK {
		defer res.Body.Close()

		err = fmt.Errorf("Unexpected response status %d fetching feed from %s",
			res.StatusCode, feedURL)

		// no feed available at the given URL, default to the English feed
		if feedURL != fallbackEndpoint {
			log.Debugf("%v; attempting to fetch fallback feed from %s",
				err, fallbackEndpoint)
			return doRequest(httpClient, fallbackEndpoint)
		} else {
			handleError(err)
			return nil, err
		}
	}
	return res, nil
}

func doGetFeed(feedEndpoint string, locale string, shouldProxy bool, allStr string,
	provider FeedProvider) {

	var res *http.Response

	var httpClient *http.Client
	var err error
	if !shouldProxy {
		// Connect directly
		httpClient = &http.Client{}
	} else {
		// Connect through proxy
		httpClient, err = getHTTPClient()
		if err != nil {
			handleError(err)
			return
		}
	}
	feed = &Feed{}

	feedURL := getFeedURL(feedEndpoint, locale)
	log.Debugf("Downloading latest feed from %s", feedURL)

	res, err = doRequest(httpClient, feedURL)
	if err != nil {
		handleError(fmt.Errorf("Error fetching feed: %v", err))
		return
	}

	defer func() {
		if err := res.Body.Close(); err != nil {
			handleError(fmt.Errorf("Error closing response body: %v", err))
		}
	}()

	gzReader, err := gzip.NewReader(res.Body)
	if err != nil {
		handleError(fmt.Errorf("Unable to open gzip reader: %s", err))
		return
	}

	defer func() {
		if err := gzReader.Close(); err != nil {
			handleError(fmt.Errorf("Unable to close gzip reader: %s", err))
		}
	}()

	contents, err := ioutil.ReadAll(gzReader)
	if err != nil {
		handleError(fmt.Errorf("Error reading feed: %v", err))
		return
	}

	err = json.Unmarshal(contents, feed)
	if err != nil {
		handleError(fmt.Errorf("Error parsing feed: %v", err))
		return
	}

	processFeed(allStr, provider)
}

// processFeed is used after a feed has been downloaded
// to extract feed sources and items for processing.
func processFeed(allStr string, provider FeedProvider) {

	log.Debugf("Num of Feed Entries: %v", len(feed.Entries))

	feed.Items = make(map[string]FeedItems)

	// Add a (shortened) description to every article
	for i, entry := range feed.Entries {
		desc := ""
		if aDesc := entry.Meta["description"]; aDesc != nil {
			desc = strings.TrimSpace(aDesc.(string))
		}

		if desc == "" {
			desc = entry.Content
		}
		feed.Entries[i].Description = desc
	}

	// the 'all' tab contains every article that's not associated with an
	// excluded feed.
	all := make(FeedItems, 0, len(feed.Entries))
	for _, entry := range feed.Entries {
		if !feed.Feeds[entry.Source].ExcludeFromAll {
			all = append(all, entry)
		}
	}
	feed.Items[allStr] = all

	// Get a list of feed sources and send those back to the UI
	for _, source := range feed.Sorted {
		if entry, exists := feed.Feeds[source]; exists {
			if entry.Title != "" {
				log.Debugf("Adding feed source: %s", entry.Title)
				provider.AddSource(entry.Title)
			} else {
				log.Errorf("Skipping feed source: %s; missing title", source)
			}
		} else {
			log.Errorf("Couldn't add feed: %s; missing from map", source)
		}
	}

	for _, s := range feed.Feeds {
		for _, i := range s.Entries {
			entry := feed.Entries[i]
			// every feed item gets appended to a feed source array
			// for quick reference
			feed.Items[s.Title] = append(feed.Items[s.Title], entry)
		}
	}
}

// GetFeedURL returns the URL to use for looking up the feed by looking up
// the users country before defaulting to the specified default locale if the
// country can't be determined.
func GetFeedURL(defaultLocale string) string {
	return getFeedURL(defaultFeedEndpoint, defaultLocale)
}

func getFeedURL(feedEndpoint, defaultLocale string) string {
	locale := determineLocale(defaultLocale)
	url := fmt.Sprintf(feedEndpoint, locale)
	log.Debugf("Returning feed URL: %v", url)
	return url
}

func determineLocale(defaultLocale string) string {
	if defaultLocale == "" {
		defaultLocale = en
	}
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
	} else if strings.EqualFold("my", country) {
		return "ms_MY"
	}
	return defaultLocale
}

func getHTTPClient() (*http.Client, error) {
	var err error
	httpClientMutex.Lock()
	if _httpClient == nil {
		var rt http.RoundTripper
		rt, err = proxied.ChainedNonPersistent("")
		if err == nil {
			_httpClient = &http.Client{Transport: rt}
		}
	}
	httpClientMutex.Unlock()
	return _httpClient, err
}
