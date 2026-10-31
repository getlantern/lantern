package lanterncore

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"

	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/vpn"

	"github.com/getlantern/lantern/lantern-core/helper"
)

// EventTypePersonalProxyFallback tells the app that the friend it had
// selected as its personal proxy lost its last route, and radiance switched
// the selection to the personal proxies group or to auto. Its message is
// {"tag": <the friend's outbound tag>, "fallback": "personal-proxies"|"auto"}.
const EventTypePersonalProxyFallback EventType = "personal-proxy-fallback"

// opPersonalProxyStatus is the HelperCall op that reads radiance's status of
// each friend this device invited. It runs outside the helper engine, so it
// never waits on the engine's lock or touches the keystore.
const opPersonalProxyStatus = "personal_proxy_status"

// opSelectedServer is the HelperCall op that reads the selection radiance
// has persisted: {"tag": <tag>}, with "auto" for auto-select. After
// connecting to a friend the app saves this, not the friend it asked for, so
// a selection radiance or the native tunnel moved elsewhere is shown as it
// is. radiance's selected-server read cannot tell auto apart from the server
// auto picked, so this reads the settings.
const opSelectedServer = "selected_server"

// personalProxyStatusTimeout bounds one status read: the app polls it while
// the server list is open, and a stale answer is worth nothing.
const personalProxyStatusTimeout = 3 * time.Second

// personalProxyStatus is one friend's entry in the status op's answer.
type personalProxyStatus struct {
	Tag    string `json:"tag"`
	Direct bool   `json:"direct"`
	Rooms  bool   `json:"rooms"`
}

// personalProxyStatusJSON reads the status of each friend this device invited
// and answers {"statuses": [{tag, direct, rooms}]}, or the helper engine's
// unavailable error when radiance does not answer (the app then treats every
// friend's status as unknown). Nothing is logged: the tags name the friends.
func personalProxyStatusJSON(ctx context.Context, read func(context.Context) ([]vpn.PersonalProxyStatus, error)) string {
	ctx, cancel := context.WithTimeout(ctx, personalProxyStatusTimeout)
	defer cancel()
	statuses, err := read(ctx)
	if err != nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeUnavailable})
	}
	out := struct {
		Statuses []personalProxyStatus `json:"statuses"`
	}{Statuses: make([]personalProxyStatus, 0, len(statuses))}
	for _, s := range statuses {
		out.Statuses = append(out.Statuses, personalProxyStatus{Tag: s.Tag, Direct: s.Direct, Rooms: s.Rooms})
	}
	b, err := json.Marshal(out)
	if err != nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeInternal})
	}
	return string(b)
}

// listenPersonalProxyFallbackEvents forwards radiance's personal proxy
// fallbacks to the app. Blocks until lc.ctx is cancelled.
func (lc *LanternCore) listenPersonalProxyFallbackEvents() {
	err := lc.client.PersonalProxyFallbackEvents(lc.ctx, func(evt vpn.PersonalProxyFallbackEvent) {
		forwardPersonalProxyFallback(evt, lc.notifyFlutter)
	})
	if err != nil && lc.ctx.Err() == nil {
		slog.Error("personal proxy fallback event stream exited unexpectedly", "error", err)
	}
}

// forwardPersonalProxyFallback sends one fallback to the app, the friend's tag
// included so the app can name them. Only a fallback radiance documents is
// sent. The log line carries neither the tag nor the fallback.
func forwardPersonalProxyFallback(evt vpn.PersonalProxyFallbackEvent, notify func(EventType, string)) {
	if evt.Tag == "" || (evt.Fallback != vpn.PersonalProxiesTag && evt.Fallback != vpn.AutoSelectTag) {
		slog.Warn("Ignoring a malformed personal proxy fallback")
		return
	}
	b, err := json.Marshal(struct {
		Tag      string `json:"tag"`
		Fallback string `json:"fallback"`
	}{evt.Tag, evt.Fallback})
	if err != nil {
		return
	}
	slog.Info("The selected personal proxy fell back")
	notify(EventTypePersonalProxyFallback, string(b))
}

// selectedServerJSON answers the selected_server op from radiance's settings.
// Nothing is logged: the tag can name a friend.
func selectedServerJSON(s settings.Settings) string {
	if auto, _ := s[settings.AutoConnectKey].(bool); auto {
		return `{"tag":"auto"}`
	}
	raw, ok := s[settings.SelectedServerKey]
	if !ok || raw == nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeUnavailable})
	}
	b, err := json.Marshal(raw)
	if err != nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeInternal})
	}
	var selected struct {
		Tag string `json:"tag"`
	}
	if json.Unmarshal(b, &selected) != nil || selected.Tag == "" {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeUnavailable})
	}
	out, err := json.Marshal(struct {
		Tag string `json:"tag"`
	}{selected.Tag})
	if err != nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeInternal})
	}
	return string(out)
}

// readSelectedServer reads radiance's settings for the selected_server op.
func (lc *LanternCore) readSelectedServer() string {
	if lc.client == nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeUnavailable})
	}
	ctx, cancel := context.WithTimeout(lc.ctx, personalProxyStatusTimeout)
	defer cancel()
	s, err := lc.client.Settings(ctx)
	if err != nil {
		return helper.ErrorJSON(&helper.Error{Code: helper.CodeUnavailable})
	}
	return selectedServerJSON(s)
}
