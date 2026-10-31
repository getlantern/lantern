package lanterncore

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/getlantern/radiance/common/settings"
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

func TestSelectedServerReadsRadiancesSelection(t *testing.T) {
	friend := map[string]any{"tag": "personal-proxy:helper-0123456789ab", "type": "mutableurltest"}
	cases := []struct {
		name string
		s    settings.Settings
		want string
	}{
		{"a friend", settings.Settings{settings.SelectedServerKey: friend}, `{"tag":"personal-proxy:helper-0123456789ab"}`},
		{"the group after a fallback", settings.Settings{settings.AutoConnectKey: false,
			settings.SelectedServerKey: map[string]any{"tag": "personal-proxies"}}, `{"tag":"personal-proxies"}`},
		{"auto wins over a stale server", settings.Settings{settings.AutoConnectKey: true,
			settings.SelectedServerKey: friend}, `{"tag":"auto"}`},
		{"nothing selected", settings.Settings{}, `{"error":"unavailable"}`},
		{"a server without a tag", settings.Settings{settings.SelectedServerKey: map[string]any{}}, `{"error":"unavailable"}`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			assert.JSONEq(t, c.want, selectedServerJSON(c.s))
		})
	}
}

func TestSelectedServerRunsWithoutTheEngine(t *testing.T) {
	lc := &LanternCore{ctx: context.Background()}
	assert.JSONEq(t, `{"error":"unavailable"}`, lc.HelperCall(opSelectedServer, "{}"))
}

// The settings endpoint answers with settings.GetAll(), Koanf's flattened
// view, sent as JSON. After an unrelated write reloads the file, the selected
// server is "selected_server.tag", not an object.
func TestSelectedServerReadsTheFlattenedSettingsShape(t *testing.T) {
	settings.Reset()
	t.Cleanup(settings.Reset)
	require.NoError(t, settings.InitSettings(t.TempDir()))
	overIPC := func() settings.Settings {
		b, err := json.Marshal(settings.GetAll())
		require.NoError(t, err)
		var s settings.Settings
		require.NoError(t, json.Unmarshal(b, &s))
		return s
	}

	require.NoError(t, settings.Patch(settings.Settings{
		settings.AutoConnectKey: false,
		settings.SelectedServerKey: map[string]any{
			"tag": "personal-proxy:helper-0123456789ab", "type": "mutableurltest",
		},
	}))
	require.NoError(t, settings.Set(settings.LocaleKey, "en-US"))
	s := overIPC()
	_, nested := s[settings.SelectedServerKey]
	assert.False(t, nested, "the shape this test is about")
	assert.Contains(t, s, settings.SelectedServerKey+".tag")
	assert.JSONEq(t, `{"tag":"personal-proxy:helper-0123456789ab"}`, selectedServerJSON(s))

	require.NoError(t, settings.Patch(settings.Settings{settings.AutoConnectKey: true}))
	require.NoError(t, settings.Set(settings.LocaleKey, "fa-IR"))
	assert.JSONEq(t, `{"tag":"auto"}`, selectedServerJSON(overIPC()))
}
