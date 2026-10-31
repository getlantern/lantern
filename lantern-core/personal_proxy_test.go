package lanterncore

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/getlantern/radiance/vpn"
)

func TestPersonalProxyStatusAnswersEachFriend(t *testing.T) {
	read := func(ctx context.Context) ([]vpn.PersonalProxyStatus, error) {
		_, ok := ctx.Deadline()
		assert.True(t, ok, "a status read is bounded")
		return []vpn.PersonalProxyStatus{
			{Tag: "helper-0123456789ab", Direct: true, DirectDelayMs: 42},
			{Tag: "helper-ba9876543210", Rooms: true},
		}, nil
	}
	assert.JSONEq(t, `{"statuses":[
		{"tag":"helper-0123456789ab","direct":true,"rooms":false},
		{"tag":"helper-ba9876543210","direct":false,"rooms":true}]}`,
		personalProxyStatusJSON(context.Background(), read))
}

func TestPersonalProxyStatusIsAnEmptyListWithNoFriends(t *testing.T) {
	read := func(context.Context) ([]vpn.PersonalProxyStatus, error) { return nil, nil }
	assert.JSONEq(t, `{"statuses":[]}`, personalProxyStatusJSON(context.Background(), read))
}

func TestPersonalProxyStatusIsUnavailableWhenRadianceIsNot(t *testing.T) {
	read := func(context.Context) ([]vpn.PersonalProxyStatus, error) {
		return nil, errors.New("ipc not running")
	}
	assert.JSONEq(t, `{"error":"unavailable"}`, personalProxyStatusJSON(context.Background(), read))
}

func TestPersonalProxyStatusRunsWithoutTheEngine(t *testing.T) {
	lc := &LanternCore{ctx: context.Background()}
	assert.JSONEq(t, `{"error":"unavailable"}`, lc.HelperCall(opPersonalProxyStatus, "{}"))
}

func TestPersonalProxyFallbackIsForwarded(t *testing.T) {
	for _, fallback := range []string{vpn.PersonalProxiesTag, vpn.AutoSelectTag} {
		var events []string
		forwardPersonalProxyFallback(vpn.PersonalProxyFallbackEvent{Tag: "helper-0123456789ab", Fallback: fallback},
			func(typ EventType, msg string) {
				assert.Equal(t, EventTypePersonalProxyFallback, typ)
				events = append(events, msg)
			})
		if assert.Len(t, events, 1) {
			assert.JSONEq(t, `{"tag":"helper-0123456789ab","fallback":"`+fallback+`"}`, events[0])
		}
	}
}

func TestMalformedPersonalProxyFallbackIsDropped(t *testing.T) {
	for _, evt := range []vpn.PersonalProxyFallbackEvent{
		{Tag: "", Fallback: vpn.AutoSelectTag},
		{Tag: "helper-0123456789ab", Fallback: "elsewhere"},
	} {
		forwardPersonalProxyFallback(evt, func(EventType, string) { t.Errorf("forwarded %+v", evt) })
	}
}
