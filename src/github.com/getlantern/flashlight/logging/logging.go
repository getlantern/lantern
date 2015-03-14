package logging

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/getlantern/appdir"
	"github.com/getlantern/flashlight/config"
	"github.com/getlantern/flashlight/globals"
	"github.com/getlantern/flashlight/util"
	"github.com/getlantern/go-loggly"
	"github.com/getlantern/golog"
	"github.com/getlantern/jibber_jabber"
	"github.com/getlantern/rotator"
	"github.com/getlantern/waitforserver"
	"github.com/getlantern/wfilter"
)

const (
	logTimestampFormat = "Jan 02 15:04:05.000"
)

var (
	log = golog.LoggerFor("flashlight.logging")

	logFile  *rotator.SizeRotator
	cfgMutex sync.Mutex

	// logglyToken is populated at build time by crosscompile.bash. During
	// development time, logglyToken will be empty and we won't log to Loggly.
	logglyToken string

	errorOut io.Writer
	debugOut io.Writer

	lastAddr string
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
	errorOut = timestamped(NonStopWriter(os.Stderr, logFile))
	debugOut = timestamped(NonStopWriter(os.Stdout, logFile))
	golog.SetOutputs(errorOut, debugOut)

	return nil
}

func Configure(cfg *config.Config, version string, buildDate string) {
	if logglyToken == "" {
		log.Debugf("No logglyToken, not sending error logs to Loggly")
		return
	}

	if version == "" {
		log.Error("No version configured, Loggly won't include version information")
		return
	}

	if buildDate == "" {
		log.Error("No build date configured, Loggly won't include build date information")
		return
	}

	cfgMutex.Lock()
	if cfg.Addr == lastAddr {
		cfgMutex.Unlock()
		log.Debug("Logging configuration unchanged")
		return
	}

	// Using a goroutine because we'll be using waitforserver and at this time
	// the proxy is not yet ready.
	go func() {
		lastAddr = cfg.Addr
		enableLoggly(cfg, version, buildDate)
		cfgMutex.Unlock()
	}()
}

func Close() error {
	golog.ResetOutputs()
	return logFile.Close()
}

// timestamped adds a timestamp to the beginning of log lines
func timestamped(orig io.Writer) io.Writer {
	return wfilter.LinePrepender(orig, func(w io.Writer) (int, error) {
		return fmt.Fprintf(w, "%s - ", time.Now().In(time.UTC).Format(logTimestampFormat))
	})
}

func enableLoggly(cfg *config.Config, version string, buildDate string) {
	if cfg.Addr == "" {
		log.Error("No known proxy, won't report to Loggly")
		removeLoggly()
		return
	}

	err := waitforserver.WaitForServer("tcp", cfg.Addr, 10*time.Second)
	if err != nil {
		log.Errorf("Proxy never came online at %v, not logging to Loggly", cfg.Addr)
		removeLoggly()
		return
	}

	var client *http.Client
	client, err = util.HTTPClient(cfg.CloudConfigCA, cfg.Addr)
	if err != nil {
		log.Errorf("Could not create proxied HTTP client, not logging to Loggly: %v", err)
		removeLoggly()
		return
	}

	log.Debugf("Sending error logs to Loggly via proxy at %v", cfg.Addr)

	lang, _ := jibber_jabber.DetectLanguage()
	logglyWriter := &logglyErrorWriter{
		lang:            lang,
		tz:              time.Now().Format("MST"),
		versionToLoggly: fmt.Sprintf("%v (%v)", version, buildDate),
		client:          loggly.New(logglyToken),
	}
	logglyWriter.client.Defaults["hostname"] = "hidden"
	logglyWriter.client.SetHTTPClient(client)
	addLoggly(logglyWriter)
}

func addLoggly(logglyWriter io.Writer) {
	golog.SetOutputs(NonStopWriter(errorOut, logglyWriter), debugOut)
}

func removeLoggly() {
	golog.SetOutputs(errorOut, debugOut)
}

type logglyErrorWriter struct {
	lang            string
	tz              string
	versionToLoggly string
	client          *loggly.Client
}

func (w logglyErrorWriter) Write(b []byte) (int, error) {
	extra := map[string]string{
		"logLevel":  "ERROR",
		"osName":    runtime.GOOS,
		"osArch":    runtime.GOARCH,
		"osVersion": "",
		"language":  w.lang,
		"country":   globals.GetCountry(),
		"timeZone":  w.tz,
		"version":   w.versionToLoggly,
	}
	fullMessage := string(b)

	// extract last 2 (at most) chunks of fullMessage to message, without prefix,
	// so we can group logs with same reason in Loggly
	parts := strings.Split(fullMessage, ":")
	var message string
	pl := len(parts)
	switch pl {
	case 1:
		message = ""
	case 2:
		message = parts[1]
	default:
		message = parts[pl-2] + ":" + parts[pl-1]
	}
	message = strings.TrimSpace(message)

	pos := strings.IndexRune(fullMessage, ':')
	if pos == -1 {
		pos = 0
	}
	prefix := fullMessage[0:pos]

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

// Write implements the method from io.Writer. It returns the smallest number
// of bytes written to any of the writers and the first error encountered in
// writing to any of the writers.
func (t *nonStopWriter) Write(p []byte) (int, error) {
	var fn int
	var ferr error
	first := true
	for _, w := range t.writers {
		n, err := w.Write(p)
		if first {
			fn, ferr = n, err
			first = false
		} else {
			// Use the smallest written n
			if n < fn {
				fn = n
			}
			// Use the first error encountered
			if ferr == nil && err != nil {
				ferr = err
			}
		}
	}

	if ferr == nil && fn < len(p) {
		ferr = io.ErrShortWrite
	}

	return fn, ferr
}
