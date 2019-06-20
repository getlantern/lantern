package feed

import (
	"net"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
)

type TestFeedProvider struct{}

type TestFeedRetriever struct{}

func (provider *TestFeedProvider) AddSource(source string) {

}

func (provider *TestFeedProvider) DisplayError(errMsg string) {

}

func (retriever *TestFeedRetriever) AddFeed(title, description,
	image, link string) {

}

func getFeed(t *testing.T, feedEndpoint string, locale string) {
	provider := &TestFeedProvider{}
	doGetFeed(feedEndpoint, locale, false, "all", provider)

	if assert.NotNil(t, CurrentFeed()) {
		assert.NotEqual(t, 0, NumFeedEntries(),
			"No feed entries after processing")
	}

	feed := CurrentFeed()

	numBuzzFeedEntries := 0
	buzzfeed := feed.Items["BuzzFeed"]
	if buzzfeed != nil {
		numBuzzFeedEntries = len(buzzfeed)
	}
	assert.Equal(t, NumFeedEntries()-numBuzzFeedEntries, len(feed.Items["all"]),
		"All feed items should be equal to total entries minus BuzzFeed entries")

	for _, entry := range feed.Items["all"] {
		assert.NotEmpty(t, entry.Title)
	}
}

func TestGetFeed(t *testing.T) {
	httpAddr := startTestServer(t)
	feedEndpoint := "http://" + httpAddr + `/%s.gz`
	locales := []string{"en_US", "fa_IR", "invalid"}
	for _, l := range locales {
		getFeed(t, feedEndpoint, l)
	}
}

func startTestServer(t *testing.T) string {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Unable to start test server: %v", err)
	}

	go func() {
		err := http.Serve(l, http.FileServer(http.Dir("feeds")))
		if err != nil {
			t.Fatalf("Unable to serve HTTP: %v", err)
		}
	}()

	return l.Addr().String()
}
