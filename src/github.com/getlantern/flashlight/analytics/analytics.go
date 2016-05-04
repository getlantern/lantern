package analytics

import (
	"bytes"
	"math"
	"net/http"
	"net/http/httputil"
	"net/url"
	"runtime"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/getlantern/eventual"
	"github.com/getlantern/flashlight/client"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/logging"
	"github.com/getlantern/flashlight/util"
	"github.com/kardianos/osext"

	"github.com/getlantern/golog"
)

const (
	trackingID = "UA-21815217-12"

	// endpoint is the endpoint to report GA data to.
	endpoint = `https://ssl.google-analytics.com/collect`
)

var (
	log = golog.LoggerFor("flashlight.analytics")

	maxWaitForIP = math.MaxInt32 * time.Second

	// This allows us to report a real user agent from clients we see on the
	// proxy.
	userAgent = eventual.NewValue()
)

// Start starts the GA session with the given data.
func Start(cfg *config.Config, version string) func() {
	var addr atomic.Value
	go func() {
		logging.AddUserAgentListener(func(agent string) {
			userAgent.Set(agent)
		})
		ip := geolookup.GetIP(maxWaitForIP)
		if ip == "" {
			log.Errorf("No IP found within %v, not starting analytics session", maxWaitForIP)
			return
		}
		addr.Store(ip)
		log.Debugf("Starting analytics session with ip %v", ip)
		startSession(ip, version, client.Addr, cfg.Client.DeviceID)
	}()

	stop := func() {
		if addr.Load() != nil {
			ip := addr.Load().(string)
			log.Debugf("Ending analytics session with ip %v", ip)
			endSession(ip, version, client.Addr, cfg.Client.DeviceID)
		}
	}
	return stop
}

func sessionVals(ip, version, clientID, sc string) string {
	vals := make(url.Values, 0)

	vals.Add("v", "1")
	vals.Add("cid", clientID)
	vals.Add("tid", trackingID)

	// Override the users IP so we get accurate geo data.
	vals.Add("uip", ip)

	// Make call to anonymize the user's IP address -- basically a policy thing where
	// Google agrees not to store it.
	vals.Add("aip", "1")

	vals.Add("dp", "localhost")
	vals.Add("t", "pageview")

	// Custom dimension for the Lantern version
	vals.Add("cd1", version)

	// Also send the app version signifier. Unclear exactly what this does for
	// web properties, but worth a try.
	vals.Add("av", version)

	// Custom dimension for the hash of the executable
	hash := getExecutableHash()
	vals.Add("cd2", hash)

	// This sets the user agent to a real user agent the user is using. We
	// wait 30 seconds for some traffic to come through.
	ua, found := userAgent.Get(30 * time.Second)
	if found {
		vals.Add("ua", ua.(string))
	}

	// This forces the recording of the session duration. It must be either
	// "start" or "end". See:
	// https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
	vals.Add("sc", sc)

	// Make this a non-interaction hit that bypasses things like bounce rate. See:
	// https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters#ni
	vals.Add("ni", "1")
	return vals.Encode()
}

// GetExecutableHash returns the hash of the currently running executable.
// If there's an error getting the hash, this returns
func getExecutableHash() string {
	// We don't know how to get a useful hash here for Android but also this
	// code isn't currently called on Android, so just guard against Something
	// bad happening here.
	if runtime.GOOS == "android" {
		return "android"
	}
	if lanternPath, err := osext.Executable(); err != nil {
		log.Debugf("Could not get path to executable %v", err)
		return err.Error()
	} else {
		if b, er := util.GetFileHash(lanternPath); er != nil {
			return er.Error()
		} else {
			return b
		}
	}
}

func endSession(ip string, version string, proxyAddrFN eventual.Getter, clientID string) {
	args := sessionVals(ip, version, clientID, "end")
	trackSession(args, proxyAddrFN)
}

func startSession(ip string, version string, proxyAddrFN eventual.Getter, clientID string) {
	args := sessionVals(ip, version, clientID, "start")
	trackSession(args, proxyAddrFN)
}

func trackSession(args string, proxyAddrFN eventual.Getter) {
	r, err := http.NewRequest("POST", endpoint, bytes.NewBufferString(args))

	if err != nil {
		log.Errorf("Error constructing GA request: %s", err)
		return
	}

	r.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	r.Header.Add("Content-Length", strconv.Itoa(len(args)))

	if req, er := httputil.DumpRequestOut(r, true); er != nil {
		log.Debugf("Could not dump request: %v", er)
	} else {
		log.Debugf("Full analytics request: %v", string(req))
	}

	var httpClient *http.Client
	httpClient, err = util.HTTPClient("", proxyAddrFN)
	if err != nil {
		log.Errorf("Could not create HTTP client: %s", err)
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
