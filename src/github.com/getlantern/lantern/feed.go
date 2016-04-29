package lantern

import (
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight"
	"github.com/getlantern/flashlight/util"
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
	Content     string                 `json:"contentText"`
	Source      string                 `json:"source"`
	Description string                 `json:"-"`
}

type FeedItems []*FeedItem

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
func GetFeed(locale string, allStr string, proxyAddr string,
	provider FeedProvider) {

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

	feedUrl := flashlight.GetFeedURL(locale)

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
