// package golog implements logging functions that log errors to stderr and
// debug messages to stdout. Trace logging is also supported. Trace logs go to
// stdout as well, but they are only written if the program is run with
// environment variable "TRACE=true"
package golog

import (
	"bufio"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strconv"
	"sync/atomic"
)

var (
	outs atomic.Value
)

func init() {
	SetOutputs(os.Stderr, os.Stdout)
}

func SetOutputs(errorOut io.Writer, debugOut io.Writer) {
	outs.Store(&outputs{
		errorOut: errorOut,
		debugOut: debugOut,
	})
}

func getOutputs() *outputs {
	return outs.Load().(*outputs)
}

type outputs struct {
	errorOut io.Writer
	debugOut io.Writer
}

type Logger interface {
	// Debug logs to stdout
	Debug(arg interface{})
	// Debugf logs to stdout
	Debugf(message string, args ...interface{})

	// Error logs to stderr
	Error(arg interface{})
	// Errorf logs to stderr
	Errorf(message string, args ...interface{})

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
}

func LoggerFor(prefix string) Logger {
	l := &logger{
		prefix: prefix + ": ",
	}
	l.traceOn, _ = strconv.ParseBool(os.Getenv("TRACE"))
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
}

func (l *logger) Debug(arg interface{}) {
	_, err := fmt.Fprintf(getOutputs().debugOut, l.prefix+"%s\n", arg)
	if err != nil {
		errorOnLogging(err)
	}
}

func (l *logger) Debugf(message string, args ...interface{}) {
	_, err := fmt.Fprintf(getOutputs().debugOut, l.prefix+message+"\n", args...)
	if err != nil {
		errorOnLogging(err)
	}
}

func (l *logger) Error(arg interface{}) {
	_, err := fmt.Fprintf(getOutputs().errorOut, l.prefix+"%s\n", arg)
	if err != nil {
		errorOnLogging(err)
	}
}

func (l *logger) Errorf(message string, args ...interface{}) {
	_, err := fmt.Fprintf(getOutputs().errorOut, l.prefix+message+"\n", args...)
	if err != nil {
		errorOnLogging(err)
	}
}

func (l *logger) Fatal(arg interface{}) {
	l.Error(arg)
	os.Exit(1)
}

func (l *logger) Fatalf(message string, args ...interface{}) {
	l.Errorf(message, args...)
	os.Exit(1)
}

func (l *logger) Trace(arg interface{}) {
	if l.traceOn {
		l.Debug(arg)
	}
}

func (l *logger) Tracef(fmt string, args ...interface{}) {
	if l.traceOn {
		l.Debugf(fmt, args...)
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

	go func() {
		defer pr.Close()
		defer pw.Close()

		for {
			line, err := br.ReadString('\n')
			if err == nil {
				// Log the line (minus the trailing newline)
				l.Trace(line[:len(line)-1])
			} else {
				l.Tracef("TraceWriter closed due to unexpected error: %v", err)
				return
			}
		}
	}()

	return pw
}

func errorOnLogging(err error) {
	fmt.Fprintf(os.Stderr, "Unable to log: %v\n", err)
}
