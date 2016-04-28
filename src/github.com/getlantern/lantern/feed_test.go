package lantern

import (
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

func getFeed(t *testing.T, locale string) {
	provider := &TestFeedProvider{}
	GetFeed(locale, "all", "", provider)

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
}

func TestGetFeed(t *testing.T) {

	locales := []string{"en_US", "fa_IR", "invalid"}
	for _, l := range locales {
		getFeed(t, l)
	}
}
