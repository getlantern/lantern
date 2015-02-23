package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/dogenzaka/rotator"
	"github.com/getlantern/appdir"
	"github.com/getlantern/golog"
	"github.com/getlantern/jibber_jabber"
	"github.com/getlantern/wfilter"
	"github.com/segmentio/go-loggly"

	"github.com/getlantern/flashlight/globals"
)

var (
	LogTimestampFormat = "Jan 02 15:04:05.000"
	log                = golog.LoggerFor("flashlight")
	versionToLoggly    = fmt.Sprintf("%v (%v)", version, buildDate)
	lang               string
	tz                 string

	// logglyToken is populated at build time by crosscompile.bash. During
	// development time, logglyToken will be empty and we won't log to Loggly.
	logglyToken string
)

func init() {
	lang, _ = jibber_jabber.DetectLanguage()
	tz = time.Local.String()
}

func configureLogging() *rotator.SizeRotator {
	logdir := appdir.Logs("Lantern")
	log.Debugf("Placing logs in %v", logdir)
	if _, err := os.Stat(logdir); err != nil {
		if os.IsNotExist(err) {
			// Create log dir
			if err := os.MkdirAll(logdir, 0755); err != nil {
				log.Fatalf("Unable to create logdir at %s: %s", logdir, err)
			}
		}
	}
	file := rotator.NewSizeRotator(filepath.Join(logdir, "lantern.log"))
	// Set log files to 1 MB
	file.RotationSize = 1 * 1024 * 1024
	// Keep up to 20 log files
	file.MaxRotation = 20

	// Loggly has its own timestamp so don't bother adding it in message,
	// moreover, golog always write each line in whole, so we need not to care about line breaks.
	errorOut := timestamped(NonStopWriter(os.Stderr, file))

	if logglyToken == "" {
		log.Debugf("No logglyToken, not sending error logs to Loggly")
	} else {
		log.Debugf("Sending error logs to Loggly")
		remoteWriter := logglyErrorWriter{loggly.New(logglyToken)}
		errorOut = NonStopWriter(errorOut, remoteWriter)
	}
	debugOut := timestamped(NonStopWriter(os.Stdout, file))
	golog.SetOutputs(errorOut, debugOut)
	return file
}

// timestamped adds a timestamp to the beginning of log lines
func timestamped(orig io.Writer) io.Writer {
	return wfilter.LinePrepender(orig, func(w io.Writer) (int, error) {
		return fmt.Fprintf(w, "%s - ", time.Now().In(time.UTC).Format(LogTimestampFormat))
	})
}

type logglyErrorWriter struct {
	l *loggly.Client
}

func (w logglyErrorWriter) Write(b []byte) (int, error) {
	return writeToLoggly(w.l, "ERROR", string(b))
}

func writeToLoggly(l *loggly.Client, level string, msg string) (int, error) {
	extra := map[string]string{
		"logLevel":  level,
		"osName":    runtime.GOOS,
		"osArch":    runtime.GOARCH,
		"osVersion": "",
		"language":  lang,
		"country":   globals.GetCountry(),
		"timeZone":  tz,
		"version":   versionToLoggly,
	}

	m := loggly.Message{
		"extra":   extra,
		"message": msg,
	}
	err := l.Send(m)
	if err != nil {
		return 0, err
	}
	return len(msg), nil
}

type nonStopWriter struct {
	writers []io.Writer
}

func (t *nonStopWriter) Write(p []byte) (n int, err error) {
	for _, w := range t.writers {
		n, _ = w.Write(p)
	}
	return len(p), nil
}

// NonStopWriter creates a writer that duplicates its writes to all the
// provided writers, even if errors encountered while writting.
func NonStopWriter(writers ...io.Writer) io.Writer {
	w := make([]io.Writer, len(writers))
	copy(w, writers)
	return &nonStopWriter{w}
}
