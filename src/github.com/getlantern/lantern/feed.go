package lantern

import (
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight/util"
)

const (
	// the Feed endpoint where recent content is published to
	// mostly just a compendium of RSS feeds
	feedEndpoint = `https://feeds.getiantem.org/%s/feed.json`
)

var (
	feed *Feed

	// locales we have separate feeds available for
	supportedLocales = map[string]bool{
		"en_US": true,
		"fa_IR": true,
		"fa":    true,
		"zh_CN": true,
	}
)

// Feed contains the data we get back
// from the public feed
type Feed struct {
	Feeds   map[string]Source    `json:"feeds"`
	Entries FeedItems            `json:"entries"`
	Items   map[string]FeedItems `json:"-"`
}

// Source represents a feed authority,
// a place where content is fetched from
// e.g. BBC, NYT, Reddit, etc.
type Source struct {
	FeedUrl string `json:"feedUrl"`
	Title   string `json:"title"`
	Url     string `json:"link"`
	Entries []int  `json:"entries"`
}

type FeedItem struct {
	Title       string                 `json:"title"`
	Link        string                 `json:"link"`
	Image       string                 `json:"image"`
	Meta        map[string]interface{} `json:"meta,omitempty"`
	Content     string                 `json:"contentText"`
	Description string                 `json:"-"`
}

type FeedItems []FeedItem

type FeedProvider interface {
	AddSource(string)
}

type FeedRetriever interface {
	AddFeed(string, string, string, string)
}

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

func CurrentFeed() *Feed {
	return feed
}

func handleError(err error) {
	feed = nil
	log.Error(err)
}

// GetFeed creates an http.Client and fetches the latest
// Lantern public feed for displaying on the home screen.
// If a proxyAddr is specified, the http.Client will proxy
// through it
func GetFeed(locale string, proxyAddr string, provider FeedProvider) {
	var err error
	var req *http.Request
	var res *http.Response
	var httpClient *http.Client

	feed = &Feed{}

	if !supportedLocales[locale] {
		// always default to English if we don't
		// have a feed available in a specific locale
		locale = "en_US"
	}

	feedUrl := fmt.Sprintf(feedEndpoint, locale)

	if req, err = http.NewRequest("GET", feedUrl, nil); err != nil {
		handleError(fmt.Errorf("Error fetching feed: %v", err))
		return
	}

	// ask for gzipped feed content
	req.Header.Add("Accept-Encoding", "gzip")

	if proxyAddr == "" {
		httpClient = &http.Client{}
	} else {
		httpClient, err = util.HTTPClient("", eventual.DefaultGetter(proxyAddr))
		if err != nil {
			handleError(fmt.Errorf("Error creating client: %v", err))
			return
		}
	}

	if res, err = httpClient.Do(req); err != nil {
		handleError(fmt.Errorf("Error fetching feed: %v", err))
		return
	}

	defer res.Body.Close()

	gzReader, err := gzip.NewReader(res.Body)
	if err != nil {
		handleError(fmt.Errorf("Unable to open gzip reader: %s", err))
		return
	}

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

	processFeed(provider)
}

// processFeed is used after a feed has been downloaded
// to extract feed sources and items for processing.
func processFeed(provider FeedProvider) {

	log.Debugf("Num of Feed Entries: %v", len(feed.Entries))

	feed.Items = make(map[string]FeedItems)

	// the 'all' tab contains every article
	feed.Items["all"] = feed.Entries

	// Get a list of feed sources & send those back to the UI
	for _, s := range feed.Feeds {
		if s.Title != "" {
			log.Debugf("Adding feed source: %s", s.Title)
			provider.AddSource(s.Title)
		}
	}

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

	for _, s := range feed.Feeds {
		for _, i := range s.Entries {
			entry := feed.Entries[i]
			// every feed item gets appended to a feed source array
			// for quick reference
			feed.Items[s.Title] = append(feed.Items[s.Title], entry)
		}
	}
}
