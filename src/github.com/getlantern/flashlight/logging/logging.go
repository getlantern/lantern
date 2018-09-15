package logging

import (
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/appdir"
	borda "github.com/getlantern/borda/client"
	"github.com/getlantern/errors"
	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/getlantern/hidden"
	"github.com/getlantern/jibber_jabber"
	"github.com/getlantern/osversion"
	"github.com/getlantern/rotator"
	"github.com/getlantern/wfilter"

	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/ops"
	"github.com/getlantern/flashlight/proxied"
)

const (
	logTimestampFormat = "Jan 02 15:04:05.000"
)

var (
	log          = golog.LoggerFor("flashlight.logging")
	processStart = time.Now()

	logFile *rotator.SizeRotator

	// logglyToken is populated at build time by crosscompile.bash. During
	// development time, logglyToken will be empty and we won't log to Loggly.
	logglyToken string
	// to show client logs in separate Loggly source group
	logglyTag = "lantern-client"

	osVersion = ""

	errorOut io.Writer
	debugOut io.Writer

	bordaClient *borda.Client

	logglyRateLimit  = 5 * time.Minute
	lastReported     = make(map[string]time.Time)
	lastReportedLock sync.Mutex

	logglyKeyTranslations = map[string]string{
		"device_id":       "instanceid",
		"os_name":         "osName",
		"os_arch":         "osArch",
		"os_version":      "osVersion",
		"locale_language": "language",
		"geo_country":     "country",
		"timezone":        "timeZone",
		"app_version":     "version",
	}
)

func init() {
	// Loggly has its own timestamp so don't bother adding it in message,
	// moreover, golog always writes each line in whole, so we need not to care
	// about line breaks.
	initLogging()
}

// EnableFileLogging enables sending Lantern logs to a file.
func EnableFileLogging() error {
	logdir := appdir.Logs("Lantern")
	log.Debugf("Placing logs in %v", logdir)
	if _, err := os.Stat(logdir); err != nil {
		if os.IsNotExist(err) {
			// Create log dir
			if err := os.MkdirAll(logdir, 0755); err != nil {
				return fmt.Errorf("Unable to create logdir at %s: %s", logdir, err)
			}
		}
	}
	logFile = rotator.NewSizeRotator(filepath.Join(logdir, "lantern.log"))
	// Set log files to 4 MB
	logFile.RotationSize = 4 * 1024 * 1024
	// Keep up to 5 log files
	logFile.MaxRotation = 5

	errorOut = timestamped(NonStopWriter(os.Stderr, logFile))
	debugOut = timestamped(NonStopWriter(os.Stdout, logFile))
	golog.SetOutputs(errorOut, debugOut)

	return nil
}

// Configure will set up logging. An empty "addr" will configure logging without a proxy
// Returns a bool channel for optional blocking.
func Configure(cloudConfigCA string, deviceID string,
	version string, revisionDate string,
	bordaReportInterval time.Duration, bordaSamplePercentage float64,
	logglySamplePercentage float64) (success chan bool) {
	success = make(chan bool, 1)

	// Note: Returning from this function must always add a result to the
	// success channel.
	if logglyToken == "" {
		log.Debugf("No logglyToken, not reporting errors")
		success <- false
		return
	}

	if version == "" {
		log.Error("No version configured, not reporting errors")
		success <- false
		return
	}

	if revisionDate == "" {
		log.Error("No build date configured, not reporting errors")
		success <- false
		return
	}

	initContext(deviceID, version, revisionDate)

	// Using a goroutine because we'll be using waitforserver and at this time
	// the proxy is not yet ready.
	go func() {
		enableLoggly(cloudConfigCA, logglySamplePercentage, deviceID)
		// Won't block, but will allow optional blocking on receiver
		success <- true
	}()

	if bordaReportInterval > 0 {
		log.Debug("Will report to borda")
		enableBorda(bordaReportInterval, bordaSamplePercentage, deviceID)
	} else {
		log.Debug("Will not report to borda")
	}

	return
}

func initContext(deviceID string, version string, revisionDate string) {
	// Using "application" allows us to distinguish between errors from the
	// lantern client vs other sources like the http-proxy, etop.
	ops.SetGlobal("app", "lantern-client")
	ops.SetGlobal("app_version", fmt.Sprintf("%v (%v)", version, revisionDate))
	ops.SetGlobal("go_version", runtime.Version())
	ops.SetGlobal("os_name", runtime.GOOS)
	ops.SetGlobal("os_arch", runtime.GOARCH)
	ops.SetGlobal("device_id", deviceID)
	ops.SetGlobalDynamic("geo_country", func() interface{} { return geolookup.GetCountry(0) })
	ops.SetGlobalDynamic("client_ip", func() interface{} { return geolookup.GetIP(0) })
	ops.SetGlobalDynamic("timezone", func() interface{} { return time.Now().Format("MST") })
	ops.SetGlobalDynamic("locale_language", func() interface{} {
		lang, _ := jibber_jabber.DetectLanguage()
		return lang
	})
	ops.SetGlobalDynamic("locale_country", func() interface{} {
		country, _ := jibber_jabber.DetectTerritory()
		return country
	})

	if osStr, err := osversion.GetHumanReadable(); err == nil {
		ops.SetGlobal("os_version", osStr)
	}
}

// SetExtraLogglyInfo supports setting an extra info value to include in Loggly
// reports (for example Android application details)
func SetExtraLogglyInfo(key, value string) {
	ops.SetGlobal(key, value)
}

// Flush forces output flushing if the output is flushable
func Flush() {
	output := golog.GetOutputs().ErrorOut
	if output, ok := output.(flushable); ok {
		output.flush()
	}
}

// Close stops logging.
func Close() error {
	if bordaClient != nil {
		bordaClient.Flush()
	}
	initLogging()
	if logFile != nil {
		return logFile.Close()
	}
	return nil
}

func initLogging() {
	errorOut = timestamped(os.Stderr)
	debugOut = timestamped(os.Stdout)
	golog.SetOutputs(errorOut, debugOut)
}

// timestamped adds a timestamp to the beginning of log lines
func timestamped(orig io.Writer) io.Writer {
	return wfilter.SimplePrepender(orig, func(w io.Writer) (int, error) {
		ts := time.Now()
		runningSecs := ts.Sub(processStart).Seconds()
		secs := int(math.Mod(runningSecs, 60))
		mins := int(runningSecs / 60)
		return fmt.Fprintf(w, "%s - %dm%ds ", ts.In(time.UTC).Format(logTimestampFormat), mins, secs)
	})
}

func enableLoggly(cloudConfigCA string, logglySamplePercentage float64, deviceID string) {
	if !includeInSample(deviceID, logglySamplePercentage) {
		log.Debugf("DeviceID %v not being sampled for Loggly", deviceID)
		return
	}
	log.Debugf("DeviceID %v will report errors to Loggly", deviceID)

	rt, err := proxied.ChainedPersistent(cloudConfigCA)
	if err != nil {
		log.Errorf("Could not create HTTP client, not logging to Loggly: %v", err)
		return
	}

	client := loggly.New(logglyToken, logglyTag)
	client.SetHTTPClient(&http.Client{Transport: rt})
	le := &logglyErrorReporter{client}
	golog.RegisterReporter(le.Report)
}

// flushable interface describes writers that can be flushed
type flushable interface {
	flush()
	Write(p []byte) (n int, err error)
}

type logglyErrorReporter struct {
	client *loggly.Client
}

func (r logglyErrorReporter) Report(err error, location string, ctx map[string]interface{}) {
	// Remove hidden errors info
	fullMessage := hidden.Clean(err.Error())
	if !shouldReport(location) {
		log.Debugf("Not reporting duplicate at %v to Loggly: %v", location, fullMessage)
		return
	}
	log.Debugf("Reporting error at %v to Loggly: %v", location, fullMessage)

	// extract last 2 (at most) chunks of fullMessage to message, so we can group
	// logs with same reason in Loggly
	var message string
	switch e := err.(type) {
	case errors.Error:
		message = e.ErrorClean()
	default:
		lastColonPos := -1
		colonsSeen := 0
		for p := len(fullMessage) - 2; p >= 0; p-- {
			if fullMessage[p] == ':' {
				lastChar := fullMessage[p+1]
				// to prevent colon in "http://" and "x.x.x.x:80" be treated as seperator
				if !(lastChar == '/' || lastChar >= '0' && lastChar <= '9') {
					lastColonPos = p
					colonsSeen++
					if colonsSeen == 2 {
						break
					}
				}
			}
		}
		if colonsSeen >= 2 {
			message = strings.TrimSpace(fullMessage[lastColonPos+1:])
		} else {
			message = fullMessage
		}
	}

	// Loggly doesn't group fields with more than 100 characters
	if len(message) > 100 {
		message = message[0:100]
	}

	translatedCtx := make(map[string]interface{}, len(ctx))
	for key, value := range ctx {
		tkey, found := logglyKeyTranslations[key]
		if !found {
			tkey = key
		}
		translatedCtx[tkey] = value
	}
	translatedCtx["sessionUserAgents"] = getSessionUserAgents()
	translatedCtx["hostname"] = "hidden"

	m := loggly.Message{
		"extra":        translatedCtx,
		"locationInfo": location,
		"message":      message,
		"fullMessage":  fullMessage,
	}

	err2 := r.client.Send(m)
	if err2 != nil {
		fmt.Fprintf(os.Stderr, "Unable to report to loggly: %v. Original error: %v\n", err2, err)
	}
}

func shouldReport(location string) bool {
	now := time.Now()
	lastReportedLock.Lock()
	defer lastReportedLock.Unlock()
	shouldReport := now.Sub(lastReported[location]) > logglyRateLimit
	if shouldReport {
		lastReported[location] = now
	}
	return shouldReport
}

// flush forces output, since it normally flushes based on an interval
func (r *logglyErrorReporter) flush() {
	if err := r.client.Flush(); err != nil {
		log.Debugf("Error flushing loggly error writer: %v", err)
	}
}

type nonStopWriter struct {
	writers []io.Writer
}

// NonStopWriter creates a writer that duplicates its writes to all the
// provided writers, even if errors encountered while writting.
func NonStopWriter(writers ...io.Writer) io.Writer {
	w := make([]io.Writer, len(writers))
	copy(w, writers)
	return &nonStopWriter{w}
}

// Write implements the method from io.Writer.
// It never fails and always return the length of bytes passed in
func (t *nonStopWriter) Write(p []byte) (int, error) {
	for _, w := range t.writers {
		// intentionally not checking for errors
		_, _ = w.Write(p)
	}
	return len(p), nil
}

// flush forces output of the writers that may provide this functionality.
func (t *nonStopWriter) flush() {
	for _, w := range t.writers {
		if w, ok := w.(flushable); ok {
			w.flush()
		}
	}
}

func enableBorda(bordaReportInterval time.Duration, bordaSamplePercentage float64, deviceID string) {
	if !includeInSample(deviceID, bordaSamplePercentage) {
		log.Debugf("DeviceID %v not being sampled for Borda", deviceID)
		return
	}

	rt := proxied.ChainedThenFronted()

	bordaClient = borda.NewClient(&borda.Options{
		BatchInterval: bordaReportInterval,
		Client: &http.Client{
			Transport: proxied.AsRoundTripper(func(req *http.Request) (*http.Response, error) {
				frontedURL := *req.URL
				frontedURL.Host = "d157vud77ygy87.cloudfront.net"
				op := ops.Begin("report_to_borda").Request(req)
				defer op.End()
				proxied.PrepareForFronting(req, frontedURL.String())
				return rt.RoundTrip(req)
			}),
		},
	})

	reportToBorda := bordaClient.ReducingSubmitter("client_results", 1000, func(existingValues map[string]float64, newValues map[string]float64) {
		for key, value := range newValues {
			existingValues[key] += value
		}
	})

	reporter := func(failure error, ctx map[string]interface{}) {
		values := map[string]float64{}
		if failure != nil {
			values["error_count"] = 1
		} else {
			values["success_count"] = 1
		}
		reportErr := reportToBorda(values, ctx)
		if reportErr != nil {
			log.Errorf("Error reporting error to borda: %v", reportErr)
		}
	}

	ops.RegisterReporter(reporter)
}

func includeInSample(deviceID string, samplePercentage float64) bool {
	if samplePercentage == 0 {
		return false
	}

	// Sample a subset of device IDs.
	// DeviceID is expected to be a Base64 encoded 48-bit (6 byte) MAC address
	deviceIDBytes, base64Err := base64.StdEncoding.DecodeString(deviceID)
	if base64Err != nil {
		log.Debugf("Error decoding base64 deviceID %v: %v", deviceID, base64Err)
		return false
	}
	if len(deviceIDBytes) != 6 {
		log.Debugf("Unexpected DeviceID length %v: %d", deviceID, len(deviceIDBytes))
		return false
	}
	// Pad and decode to int
	paddedDeviceIDBytes := append(deviceIDBytes, 0, 0)
	deviceIDInt := binary.BigEndian.Uint64(paddedDeviceIDBytes)
	return deviceIDInt%uint64(1/samplePercentage) == 0
}
