package analytics

import (
	"bytes"
	"net/http"
	"net/url"
	"runtime"
	"strconv"

	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/golog"
)

const (
	ApiEndpoint       = `https://ssl.google-analytics.com/collect`
	ProtocolVersion   = "1"
	DefaultInstanceId = "555"
)

var (
	log        = golog.LoggerFor("analytics")
	httpClient *http.Client
)

type HitType string

const (
	PageViewType HitType = "pageview"
	EventType    HitType = "event"
)

type PageView struct {
	Hostname string `param:"dh"`
	Pagename string `param:"dp"`
	Title    string `param:"dt"`
}

type Event struct {
	Category string `param:"ec"`
	Action   string `param:"ea"`
	Label    string `param:"el,omitempty"`
	Value    string `param:"ev,omitempty"`
}

type Payload struct {
	InstanceId string `json:"clientId"`

	ClientVersion string `json:"clientVersion,omitempty"`

	ViewPortSize string `json:"viewPortSize,omitempty"`

	TrackingId string `json:"trackingId"`

	Language string `json:"language,omitempty"`

	ScreenColors string `json:"screenColors,omitempty"`

	ScreenResolution string `json:"screenResolution,omitempty"`

	Hostname string `json:"hostname,omitempty"`

	HitType HitType `json:"hitType,omitempty"`

	CustomVars map[string]string

	UserAgent string

	Event *Event
}

func Configure(trackingId string, version string, proxyAddr string) {
	var err error
	go func() {
		httpClient, err = util.HTTPClient("", proxyAddr)
		if err != nil {
			log.Errorf("Could not create HTTP client via %s: %s", proxyAddr, err)
			return
		}
		// Store new session info whenever client proxy is ready
		sessionEvent(trackingId, version)
	}()
}

// assemble list of parameters to send to GA
func collectArgs(payload *Payload) string {
	vals := make(url.Values, 0)

	// Add default payload
	vals.Add("v", ProtocolVersion)
	if payload.ClientVersion != "" {
		vals.Add("_v", payload.ClientVersion)
	}
	if payload.TrackingId != "" {
		vals.Add("tid", payload.TrackingId)
	}
	if payload.InstanceId != "" {
		vals.Add("cid", payload.InstanceId)
	}
	if payload.ScreenResolution != "" {
		vals.Add("sr", payload.ScreenResolution)
	}
	if payload.Language != "" {
		vals.Add("ul", payload.Language)
	}

	vals.Add("t", string(payload.HitType))

	if payload.HitType == EventType && payload.Event != nil {
		vals.Add("ec", payload.Event.Category)
		vals.Add("ea", payload.Event.Action)
		if payload.Event.Label != "" {
			vals.Add("el", payload.Event.Label)
		}
		if payload.Event.Value != "" {
			vals.Add("ev", payload.Event.Value)
		}
	}

	for dim, customVar := range payload.CustomVars {
		if customVar != "" {
			vals.Add(dim, customVar)
		}
	}

	return vals.Encode()
}

// Makes a tracking request to Google Analytics
func SendRequest(payload *Payload) (status bool, err error) {
	if httpClient == nil {
		log.Error("No HTTP client; could not send HTTP request to GA")
		return false, nil
	}

	args := collectArgs(payload)

	r, err := http.NewRequest("POST", ApiEndpoint, bytes.NewBufferString(args))
	r.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Add("Content-Length", strconv.Itoa(len(args)))

	if err != nil {
		log.Errorf("Error constructing GA request: %s", err)
		return false, err
	}

	resp, err := httpClient.Do(r)
	if err != nil {
		log.Errorf("Could not send HTTP request to GA: %s", err)
		return false, err
	}
	log.Debugf("Successfully sent request to GA: %s", resp.Status)
	defer resp.Body.Close()

	return true, nil
}

// Fired whenever a new Lanern session is initiated
func sessionEvent(trackingId string, version string) (status bool, err error) {

	sessionPayload := &Payload{
		HitType:    EventType,
		TrackingId: trackingId,
		InstanceId: DefaultInstanceId,
		Event: &Event{
			Category: "Session",
			Action:   "Start",
			Label:    runtime.GOOS,
		},
	}

	if version != "" {
		sessionPayload.CustomVars = map[string]string{
			"cd1": version,
		}
	}
	return SendRequest(sessionPayload)
}
