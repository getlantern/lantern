package logging

import (
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/appdir"
	"github.com/getlantern/flashlight/geolookup"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/getlantern/jibber_jabber"
	"github.com/getlantern/osversion"
	"github.com/getlantern/rotator"
	"github.com/getlantern/wfilter"
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

	osVersion = ""

	errorOut io.Writer
	debugOut io.Writer

	lastAddr   string
	duplicates = make(map[string]bool)
	dupLock    sync.Mutex
)

func Init() error {
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
	// Set log files to 1 MB
	logFile.RotationSize = 1 * 1024 * 1024
	// Keep up to 20 log files
	logFile.MaxRotation = 20

	// Loggly has its own timestamp so don't bother adding it in message,
	// moreover, golog always write each line in whole, so we need not to care about line breaks.

	// timestamped adds a timestamp to the beginning of log lines
	timestamped := func(orig io.Writer) io.Writer {
		return wfilter.SimplePrepender(orig, func(w io.Writer) (int, error) {
			ts := time.Now()
			runningSecs := ts.Sub(processStart).Seconds()
			secs := int(math.Mod(runningSecs, 60))
			mins := int(runningSecs / 60)
			return fmt.Fprintf(w, "%s - %dm%ds ", ts.In(time.UTC).Format(logTimestampFormat), mins, secs)
		})
	}

	errorOut = timestamped(NonStopWriter(os.Stderr, logFile))
	debugOut = timestamped(NonStopWriter(os.Stdout, logFile))
	golog.SetOutputs(errorOut, debugOut)

	return nil
}

// Configure will set up logging. An empty "addr" will configure logging without a proxy
// Returns a bool channel for optional blocking.
func Configure(addr string, cloudConfigCA string, instanceId string,
	version string, revisionDate string) (success chan bool) {
	success = make(chan bool, 1)

	// Note: Returning from this function must always add a result to the
	// success channel.
	if logglyToken == "" {
		log.Debugf("No logglyToken, not sending error logs to Loggly")
		success <- false
		return
	}

	if version == "" {
		log.Error("No version configured, not sending error logs to Loggly")
		success <- false
		return
	}

	if revisionDate == "" {
		log.Error("No build date configured, not sending error logs to Loggly")
		success <- false
		return
	}

	if addr != "" && addr == lastAddr {
		log.Debug("Logging configuration unchanged")
		success <- false
		return
	}

	// Using a goroutine because we'll be using waitforserver and at this time
	// the proxy is not yet ready.
	go func() {
		lastAddr = addr
		enableLoggly(addr, cloudConfigCA, instanceId, version, revisionDate)
		// Won't block, but will allow optional blocking on receiver
		success <- true
	}()
	return
}

// Flush forces output flushing if the output is flushable
func Flush() {
	output := golog.GetOutputs().ErrorOut
	if output, ok := output.(flushable); ok {
		output.flush()
	}
}

func Close() error {
	golog.ResetOutputs()
	return logFile.Close()
}

func enableLoggly(addr string, cloudConfigCA string, instanceId string,
	version string, revisionDate string) {

	client, err := util.PersistentHTTPClient(cloudConfigCA, addr)
	if err != nil {
		log.Errorf("Could not create HTTP client, not logging to Loggly: %v", err)
		removeLoggly()
		return
	}

	if addr == "" {
		log.Debugf("Sending error logs to Loggly directly")
	} else {
		log.Debugf("Sending error logs to Loggly via proxy at %v", addr)
	}

	lang, _ := jibber_jabber.DetectLanguage()
	logglyWriter := &logglyErrorWriter{
		lang:            lang,
		tz:              time.Now().Format("MST"),
		versionToLoggly: fmt.Sprintf("%v (%v)", version, revisionDate),
		client:          loggly.New(logglyToken),
	}
	logglyWriter.client.Defaults["hostname"] = "hidden"
	logglyWriter.client.Defaults["instanceid"] = instanceId
	if osStr, err := osversion.GetHumanReadable(); err == nil {
		osVersion = osStr
	}
	logglyWriter.client.SetHTTPClient(client)
	addLoggly(logglyWriter)
}

func addLoggly(logglyWriter io.Writer) {
	if runtime.GOOS == "android" {
		golog.SetOutputs(logglyWriter, os.Stdout)
	} else {
		golog.SetOutputs(NonStopWriter(errorOut, logglyWriter), debugOut)
	}
}

func removeLoggly() {
	golog.SetOutputs(errorOut, debugOut)
}

func isDuplicate(msg string) bool {
	dupLock.Lock()
	defer dupLock.Unlock()

	if duplicates[msg] {
		return true
	}

	// Implement a crude cap on the size of the map
	if len(duplicates) < 1000 {
		duplicates[msg] = true
	}

	return false
}

// flushable interface describes writers that can be flushed
type flushable interface {
	flush()
	Write(p []byte) (n int, err error)
}

type logglyErrorWriter struct {
	lang            string
	tz              string
	versionToLoggly string
	client          *loggly.Client
}

func (w logglyErrorWriter) Write(b []byte) (int, error) {
	fullMessage := string(b)
	if isDuplicate(fullMessage) {
		log.Debugf("Not logging duplicate: %v", fullMessage)
		return 0, nil
	}

	extra := map[string]string{
		"logLevel":          "ERROR",
		"osName":            runtime.GOOS,
		"osArch":            runtime.GOARCH,
		"osVersion":         osVersion,
		"language":          w.lang,
		"country":           geolookup.GetCountry(),
		"timeZone":          w.tz,
		"version":           w.versionToLoggly,
		"sessionUserAgents": getSessionUserAgents(),
	}

	// extract last 2 (at most) chunks of fullMessage to message, without prefix,
	// so we can group logs with same reason in Loggly
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
	message := strings.TrimSpace(fullMessage[lastColonPos+1:])

	// Loggly doesn't group fields with more than 100 characters
	if len(message) > 100 {
		message = message[0:100]
	}

	firstColonPos := strings.IndexRune(fullMessage, ':')
	if firstColonPos == -1 {
		firstColonPos = 0
	}
	prefix := fullMessage[0:firstColonPos]

	m := loggly.Message{
		"extra":        extra,
		"locationInfo": prefix,
		"message":      message,
		"fullMessage":  fullMessage,
	}

	err := w.client.Send(m)
	if err != nil {
		return 0, err
	}
	return len(b), nil
}

// flush forces output, since it normally flushes based on an interval
func (w *logglyErrorWriter) flush() {
	if err := w.client.Flush(); err != nil {
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
		if n, err := w.Write(p); err != nil {
			return n, err
		}
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
