package client

import (
	"net/http"
	"runtime"

	"github.com/getlantern/analytics"
	"github.com/getlantern/flashlight/util"
)

func (client *Client) initAnalytics() {
	var err error
	var cli *http.Client

	if cli, err = util.HTTPClient(cloudConfigCA, client.addr); err != nil {
		return
	}

	sessionPayload := &analytics.Payload{
		HitType:  analytics.EventType,
		Hostname: "localhost",
		Event: &analytics.Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
	}
	analytics.SessionEvent(cli, sessionPayload)
}
