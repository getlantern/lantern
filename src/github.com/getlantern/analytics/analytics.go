package analytics

import (
	"fmt"
	"net/http"
	"net/url"

	"github.com/getlantern/golog"
)

const (
	ApiEndpoint     = `https://www.google-analytics.com/collect?%s`
	ProtocolVersion = "1"
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
	HitType  HitType `param:"t"`
	Hostname string  `param:"dh"`
	Pagename string  `param:"dp"`
	Title    string  `param:"dt"`
}

type Event struct {
	HitType  HitType `param:"t"`
	Category string  `param:"ec"`
	Action   string  `param:"ea"`
	Label    string  `param:"el,omitempty"`
	Value    string  `param:"ev,omitempty"`
}

type Payload struct {
	ClientId string `json:"clientId"`

	ClientVersion string `json:"clientVersion,omitempty"`

	ViewPortSize string `json:"viewPortSize,omitempty"`

	TrackingId string `json:"trackingId"`

	Language string `json:"language,omitempty"`

	ScreenColors string `json:"screenColors,omitempty"`

	ScreenResolution string `json:"screenResolution,omitempty"`
}

// attaach list of parameters to request
func composeUrl(payload *Payload) string {
	vals := make(url.Values, 0)

	// Add default payload
	vals.Add("v", ProtocolVersion)
	vals.Add("_v", payload.ClientVersion)
	vals.Add("tid", payload.TrackingId)
	vals.Add("cid", payload.ClientId)
	vals.Add("sr", payload.ScreenResolution)
	vals.Add("ul", payload.Language)

	vals.Add("t", string(PageViewType))

	return fmt.Sprintf(ApiEndpoint, vals.Encode())
}

// Makes a tracking request to Google Analytics
func SendRequest(httpClient *http.Client, payload *Payload) (status bool, err error) {
	if httpClient == nil {
		log.Trace("Using default http.Client")
		httpClient = defaultHttpClient
	}

	url := composeUrl(payload)

	if _, err = http.Get(url); err != nil {
		log.Errorf("Could not send request to Google Analytics: %q", err)
		return false, err
	}

	return true, nil
}
