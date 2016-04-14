package lantern

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

var (
	items FeedItems
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
	var err error

	provider := &TestFeedProvider{}
	err = GetFeed(locale, "", provider)
	count := NumFeedEntries()

	if assert.NoError(t, err) {
		assert.NotEqual(t, 0, count,
			"No feed entries after processing")
	}

	feed := CurrentFeed()

	assert.Equal(t, count, len(feed.Items["all"]),
		"All feed items should be equal to total entries")
}

func TestGetFeed(t *testing.T) {

	locales := []string{"en_US", "zh_CN", "invalid"}
	for _, l := range locales {
		getFeed(t, l)
	}
}
