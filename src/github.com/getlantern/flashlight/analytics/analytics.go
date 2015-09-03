package analytics

import (
	"bytes"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"

	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/pubsub"
	"github.com/getlantern/flashlight/util"

	"github.com/getlantern/golog"
)

const (
	trackingId  = "UA-21815217-12"
	ApiEndpoint = `https://ssl.google-analytics.com/collect`
)

var (
	log = golog.LoggerFor("flashlight.analytics")
)

func Configure(cfg *config.Config, version string) func() {
	if cfg.AutoReport != nil && *cfg.AutoReport {
		addr := ""
		pubsub.Sub(pubsub.IP, func(ip string) {
			log.Debugf("Got IP %v -- starting analytics", ip)
			addr = ip
			go startSession(ip, version, cfg.Addr, cfg.InstanceId)
		})
		return func() {
			if addr != "" {
				log.Debugf("Ending analytics session with ip %v", addr)
				endSession(addr, version, cfg.Addr, cfg.InstanceId)
			}
		}
	}
	return func() {}
}

func sessionVals(ip string, version string, clientId string, sc string) string {
	vals := make(url.Values, 0)

	vals.Add("v", "1")
	vals.Add("cid", clientId)
	vals.Add("tid", trackingId)

	// Override the users IP so we get accurate geo data.
	vals.Add("uip", ip)

	// Make call to anonymize the user's IP address -- basically a policy thing where
	// Google agrees not to store it.
	vals.Add("aip", "1")

	vals.Add("dp", "localhost")
	vals.Add("t", "pageview")

	// Custom variable for the Lantern version
	vals.Add("cd1", version)

	// This forces the recording of the session duration. It must be either
	// "start" or "end". See:
	// https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
	vals.Add("sc", sc)
	return vals.Encode()
}

func endSession(ip, version, proxyAddr, clientId string) {
	args := sessionVals(ip, version, clientId, "end")
	trackSession(args, proxyAddr)
}

func startSession(ip, version, proxyAddr, clientId string) {
	args := sessionVals(ip, version, clientId, "start")
	trackSession(args, proxyAddr)
}

func trackSession(args, proxyAddr string) {
	r, err := http.NewRequest("POST", ApiEndpoint, bytes.NewBufferString(args))

	if err != nil {
		log.Errorf("Error constructing GA request: %s", err)
		return
	}

	r.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Add("Content-Length", strconv.Itoa(len(args)))

	if req, err := httputil.DumpRequestOut(r, true); err != nil {
		log.Debugf("Could not dump request: %v", err)
	} else {
		log.Debugf("Full analytics request: %v", string(req))
	}

	var httpClient *http.Client
	httpClient, err = util.HTTPClient("", proxyAddr)
	if err != nil {
		log.Errorf("Could not create HTTP client via %s: %s", proxyAddr, err)
		return
	}
	resp, err := httpClient.Do(r)
	if err != nil {
		log.Errorf("Could not send HTTP request to GA: %s", err)
		return
	}
	log.Debugf("Successfully sent request to GA: %s", resp.Status)
	if err := resp.Body.Close(); err != nil {
		log.Debugf("Unable to close response body: %v", err)
	}
}
