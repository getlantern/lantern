package analytics

import (
	"bytes"
	"net/http"
	"net/http/httputil"
	"net/url"
	"runtime"
	"strconv"

	"github.com/getlantern/eventual"
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
	ip         string
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

	UserAgent string

	Event *Event
}

func Configure(addr string, trackingId string, version string, proxyAddr string) {
	ip = addr
	var err error
	go func() {
		httpClient, err = util.HTTPClient("", eventual.DefaultGetter(proxyAddr))
		if err != nil {
			log.Errorf("Could not create HTTP client via %s: %s", proxyAddr, err)
			return
		}
		// Store new session info whenever client proxy is ready
		if status, err := sessionEvent(trackingId, version); err != nil {
			log.Errorf("Unable to store new session info: %v", err)
		} else {
			log.Tracef("Storing new session info: %v", status)
		}
	}()
}

// assemble list of parameters to send to GA
func collectArgs(payload *Payload) string {
	vals := make(url.Values, 0)

	// Add default payload
	vals.Add("v", ProtocolVersion)

	// Override the users IP so we get accurate geo data.
	vals.Add("uip", ip)

	// Make call to anonymize the user's IP address.
	vals.Add("aip", "1")

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

	if err != nil {
		log.Errorf("Error constructing GA request: %s", err)
		return false, err
	}

	r.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Add("Content-Length", strconv.Itoa(len(args)))

	if req, err := httputil.DumpRequestOut(r, true); err != nil {
		log.Debugf("Could not dump request: %v", err)
	} else {
		log.Debugf("Full analytics request: %v", string(req))
	}

	resp, err := httpClient.Do(r)
	if err != nil {
		log.Errorf("Could not send HTTP request to GA: %s", err)
		return false, err
	}
	log.Debugf("Successfully sent request to GA: %s", resp.Status)
	defer func() {
		if err := resp.Body.Close(); err != nil {
			log.Debugf("Unable to close response body: %v", err)
		}
	}()
	return true, nil
}

// Fired whenever a new Lanern session is initiated
func sessionEvent(trackingId string, version string) (status bool, err error) {

	sessionPayload := &Payload{
		HitType:    EventType,
		TrackingId: trackingId,
		Hostname:   "localhost",
		ClientId:   DefaultInstanceId,
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
