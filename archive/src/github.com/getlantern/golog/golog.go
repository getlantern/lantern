// Package golog implements logging functions that log errors to stderr and
// debug messages to stdout. Trace logging is also supported.
// Trace logs go to stdout as well, but they are only written if the program
// is run with environment variable "TRACE=true".
package golog

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/getlantern/errors"
	"github.com/getlantern/hidden"
	"github.com/getlantern/ops"
	"github.com/oxtoacart/bpool"
)

var (
	outs           atomic.Value
	reporters      []ErrorReporter
	reportersMutex sync.RWMutex

	bufferPool = bpool.NewBufferPool(200)
)

func init() {
	ResetOutputs()
}

func SetOutputs(errorOut io.Writer, debugOut io.Writer) {
	outs.Store(&outputs{
		ErrorOut: errorOut,
		DebugOut: debugOut,
	})
}

func ResetOutputs() {
	SetOutputs(os.Stderr, os.Stdout)
}

func GetOutputs() *outputs {
	return outs.Load().(*outputs)
}

// RegisterReporter registers the given ErrorReporter. All logged Errors are
// sent to this reporter.
func RegisterReporter(reporter ErrorReporter) {
	reportersMutex.Lock()
	reporters = append(reporters, reporter)
	reportersMutex.Unlock()
}

type outputs struct {
	ErrorOut io.Writer
	DebugOut io.Writer
}

// ErrorReporter is a function to which the logger will report errors.
// It the given error and corresponding message along with associated ops
// context. This should return quickly as it executes on the critical code
// path. The recommended approach is to buffer as much as possible and discard
// new reports if the buffer becomes saturated.
type ErrorReporter func(err error, linePrefix string, ctx map[string]interface{})

type Logger interface {
	// Debug logs to stdout
	Debug(arg interface{})
	// Debugf logs to stdout
	Debugf(message string, args ...interface{})

	// Error logs to stderr
	Error(arg interface{}) error
	// Errorf logs to stderr. It returns the first argument that's an error, or
	// a new error built using fmt.Errorf if none of the arguments are errors.
	Errorf(message string, args ...interface{}) error

	// Fatal logs to stderr and then exits with status 1
	Fatal(arg interface{})
	// Fatalf logs to stderr and then exits with status 1
	Fatalf(message string, args ...interface{})

	// Trace logs to stderr only if TRACE=true
	Trace(arg interface{})
	// Tracef logs to stderr only if TRACE=true
	Tracef(message string, args ...interface{})

	// TraceOut provides access to an io.Writer to which trace information can
	// be streamed. If running with environment variable "TRACE=true", TraceOut
	// will point to os.Stderr, otherwise it will point to a ioutil.Discared.
	// Each line of trace information will be prefixed with this Logger's
	// prefix.
	TraceOut() io.Writer

	// IsTraceEnabled() indicates whether or not tracing is enabled for this
	// logger.
	IsTraceEnabled() bool

	// AsStdLogger returns an standard logger
	AsStdLogger() *log.Logger
}

func LoggerFor(prefix string) Logger {

	l := &logger{
		prefix: prefix + ": ",
		pc:     make([]uintptr, 10),
	}

	trace := os.Getenv("TRACE")
	l.traceOn, _ = strconv.ParseBool(trace)
	if !l.traceOn {
		prefixes := strings.Split(trace, ",")
		for _, p := range prefixes {
			if prefix == strings.Trim(p, " ") {
				l.traceOn = true
				break
			}
		}
	}
	if l.traceOn {
		l.traceOut = l.newTraceWriter()
	} else {
		l.traceOut = ioutil.Discard
	}

	return l
}

type logger struct {
	prefix   string
	traceOn  bool
	traceOut io.Writer
	outs     atomic.Value
	pc       []uintptr
}

// attaches the file and line number corresponding to
// the log message
func (l *logger) linePrefix(skipFrames int) string {
	runtime.Callers(skipFrames, l.pc)
	funcForPc := runtime.FuncForPC(l.pc[0])
	file, line := funcForPc.FileLine(l.pc[0] - 1)
	return fmt.Sprintf("%s%s:%d ", l.prefix, filepath.Base(file), line)
}

func (l *logger) print(out io.Writer, skipFrames int, severity string, arg interface{}) string {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)

	linePrefix := l.linePrefix(skipFrames)
	sp := severity + " " + linePrefix
	buf.WriteString(sp)
	if arg != nil {
		if err, isError := arg.(errors.Error); isError && err != nil {
			buf.WriteString(err.Error())
			printContext(buf, arg)
			buf.WriteByte('\n')
			if severity == "FATAL" || severity == "ERROR" {
				err.PrintStack(buf, sp)
			}
		} else {
			fmt.Fprintf(buf, "%v", arg)
			printContext(buf, arg)
			buf.WriteByte('\n')
		}
	}
	b := []byte(hidden.Clean(buf.String()))
	_, err := out.Write(b)
	if err != nil {
		errorOnLogging(err)
	}
	return linePrefix
}

func (l *logger) printf(out io.Writer, skipFrames int, severity string, err error, message string, args ...interface{}) string {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)

	linePrefix := l.linePrefix(skipFrames)
	buf.WriteString(severity)
	buf.WriteString(" ")
	buf.WriteString(linePrefix)
	fmt.Fprintf(buf, message, args...)
	printContext(buf, err)
	buf.WriteByte('\n')
	b := []byte(hidden.Clean(buf.String()))
	_, err2 := out.Write(b)
	if err2 != nil {
		errorOnLogging(err)
	}
	return linePrefix
}

func (l *logger) Debug(arg interface{}) {
	l.print(GetOutputs().DebugOut, 4, "DEBUG", arg)
}

func (l *logger) Debugf(message string, args ...interface{}) {
	l.printf(GetOutputs().DebugOut, 4, "DEBUG", nil, message, args...)
}

func (l *logger) Error(arg interface{}) error {
	return l.errorSkipFrames(arg, 1)
}

func (l *logger) errorSkipFrames(arg interface{}, skipFrames int) error {
	var err error
	switch e := arg.(type) {
	case error:
		err = e
	default:
		err = fmt.Errorf("%v", e)
	}
	linePrefix := l.print(GetOutputs().ErrorOut, skipFrames+4, "ERROR", err)
	return report(err, linePrefix)
}

func (l *logger) Errorf(message string, args ...interface{}) error {
	return l.errorSkipFrames(errors.NewOffset(1, message, args...), 1)
}

func (l *logger) Fatal(arg interface{}) {
	l.print(GetOutputs().ErrorOut, 4, "FATAL", arg)
	os.Exit(1)
}

func (l *logger) Fatalf(message string, args ...interface{}) {
	l.printf(GetOutputs().ErrorOut, 4, "FATAL", nil, message, args...)
	os.Exit(1)
}

func (l *logger) Trace(arg interface{}) {
	if l.traceOn {
		l.print(GetOutputs().DebugOut, 4, "TRACE", arg)
	}
}

func (l *logger) Tracef(message string, args ...interface{}) {
	if l.traceOn {
		l.printf(GetOutputs().DebugOut, 4, "TRACE", nil, message, args...)
	}
}

func (l *logger) TraceOut() io.Writer {
	return l.traceOut
}

func (l *logger) IsTraceEnabled() bool {
	return l.traceOn
}

func (l *logger) newTraceWriter() io.Writer {
	pr, pw := io.Pipe()
	br := bufio.NewReader(pr)

	if !l.traceOn {
		return pw
	}
	go func() {
		defer func() {
			if err := pr.Close(); err != nil {
				errorOnLogging(err)
			}
		}()
		defer func() {
			if err := pw.Close(); err != nil {
				errorOnLogging(err)
			}
		}()

		for {
			line, err := br.ReadString('\n')
			if err == nil {
				// Log the line (minus the trailing newline)
				l.print(GetOutputs().DebugOut, 6, "TRACE", line[:len(line)-1])
			} else {
				l.printf(GetOutputs().DebugOut, 6, "TRACE", nil, "TraceWriter closed due to unexpected error: %v", err)
				return
			}
		}
	}()

	return pw
}

type errorWriter struct {
	l *logger
}

// Write implements method of io.Writer, due to different call depth,
// it will not log correct file and line prefix
func (w *errorWriter) Write(p []byte) (n int, err error) {
	s := string(p)
	if s[len(s)-1] == '\n' {
		s = s[:len(s)-1]
	}
	w.l.print(GetOutputs().ErrorOut, 6, "ERROR", s)
	return len(p), nil
}

func (l *logger) AsStdLogger() *log.Logger {
	return log.New(&errorWriter{l}, "", 0)
}

func errorOnLogging(err error) {
	fmt.Fprintf(os.Stderr, "Unable to log: %v\n", err)
}

func printContext(buf *bytes.Buffer, err interface{}) {
	// Note - we don't include globals when printing in order to avoid polluting the text log
	values := ops.AsMap(err, false)
	if len(values) == 0 {
		return
	}
	buf.WriteString(" [")
	var keys []string
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for i, key := range keys {
		value := values[key]
		if i > 0 {
			buf.WriteString(" ")
		}
		buf.WriteString(key)
		buf.WriteString("=")
		fmt.Fprintf(buf, "%v", value)
	}
	buf.WriteByte(']')
}

func report(err error, linePrefix string) error {
	var reportersCopy []ErrorReporter
	reportersMutex.RLock()
	if len(reporters) > 0 {
		reportersCopy = make([]ErrorReporter, len(reporters))
		copy(reportersCopy, reporters)
	}
	reportersMutex.RUnlock()

	if len(reportersCopy) > 0 {
		ctx := ops.AsMap(err, true)
		for _, reporter := range reportersCopy {
			// We include globals when reporting
			reporter(err, linePrefix, ctx)
		}
	}
	return err
}
