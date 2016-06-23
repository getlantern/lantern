package app

import (
	"testing"

	"github.com/getlantern/bandwidth"
	"github.com/stretchr/testify/assert"
)

func TestPercents(t *testing.T) {
	ns = notifyStatus{}

	quota := &bandwidth.Quota{
		MiBAllowed: 1000,
		MiBUsed:    801,
	}

	assert.True(t, ns.isEightyOrMore(quota))

	quota.MiBUsed = 501
	assert.False(t, ns.isEightyOrMore(quota))
	assert.True(t, ns.isFiftyOrMore(quota))

	msg := "you have used %s of your data"
	expected := "you have used 80% of your data"
	assert.Equal(t, expected, ns.percentMsg(msg, 80))
}
