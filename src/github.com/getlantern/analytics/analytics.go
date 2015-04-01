package analytics

import (
	"fmt"
	"net/http"
	"net/url"

	"github.com/getlantern/golog"
)

const (
	ApiEndpoint          = `https://www.google-analytics.com/collect?%s`
	ProtocolVersion      = "1"
	DefaultClientVersion = "1"
	TrackingId           = "UA-21815217-2"
	DefaultClientId      = "555"
)

var (
	log = golog.LoggerFor("analytics")

	defaultHttpClient = &http.Client{}
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
	ClientId string `json:"clientId"`

	ClientVersion string `json:"clientVersion,omitempty"`

	ViewPortSize string `json:"viewPortSize,omitempty"`

	TrackingId string `json:"trackingId"`

	Language string `json:"language,omitempty"`

	ScreenColors string `json:"screenColors,omitempty"`

	ScreenResolution string `json:"screenResolution,omitempty"`

	Hostname string `json:"hostname,omitempty"`

	HitType HitType `json:"hitType,omitempty"`

	CustomVars map[string]string

	Event *Event
}

// attaach list of parameters to request
func composeUrl(payload *Payload) string {
	vals := make(url.Values, 0)

	// Add default payload
	vals.Add("v", ProtocolVersion)
	if payload.ClientVersion != "" {
		vals.Add("_v", payload.ClientVersion)
	}
	if payload.TrackingId != "" {
		vals.Add("tid", payload.TrackingId)
	}
	if payload.ClientId != "" {
		vals.Add("cid", payload.ClientId)
	}
	if payload.ScreenResolution != "" {
		vals.Add("sr", payload.ScreenResolution)
	}
	if payload.Language != "" {
		vals.Add("ul", payload.Language)
	}

	vals.Add("dh", payload.Hostname)

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

	return fmt.Sprintf(ApiEndpoint, vals.Encode())
}

// Makes a tracking request to Google Analytics
func SendRequest(httpClient *http.Client, payload *Payload) (status bool, err error) {
	var resp *http.Response

	if httpClient == nil {
		log.Trace("Using default http.Client")
		httpClient = defaultHttpClient
	}

	url := composeUrl(payload)
	log.Debugf("New Google Analytics request: %s", url)

	if resp, err = http.Get(url); err != nil {
		log.Errorf("Could not send request to Google Analytics: %q", err)
		return false, err
	}
	defer resp.Body.Close()

	return true, nil
}

// This event is fired whenever the client opens a new UI session
func UIEvent(httpClient *http.Client, payload *Payload) (status bool, err error) {
	return SendRequest(httpClient, payload)
}

// Fired whenever a new Lanern session is initiated
func SessionEvent(httpClient *http.Client, payload *Payload) (status bool, err error) {
	// add tracking Id since this won't be present already
	payload.TrackingId = TrackingId
	payload.ClientId = DefaultClientId
	return SendRequest(httpClient, payload)
}
