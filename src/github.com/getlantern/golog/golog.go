// package golog implements logging functions that log errors to stderr and
// debug messages to stdout. Trace logging is also supported.
// Trace logs go to stdout as well, but they are only written if the program
// is run with environment variable "TRACE=true".
// A stack dump will be printed after the message if "PRINT_STACK=true".
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
	"strconv"
	"strings"
	"sync/atomic"

	"github.com/getlantern/ctx"
	"github.com/oxtoacart/bpool"
)

var (
	outs atomic.Value

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

type outputs struct {
	ErrorOut io.Writer
	DebugOut io.Writer
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

	printStack := os.Getenv("PRINT_STACK")
	l.printStack, _ = strconv.ParseBool(printStack)

	return l
}

type logger struct {
	prefix     string
	traceOn    bool
	traceOut   io.Writer
	printStack bool
	outs       atomic.Value
	pc         []uintptr
	funcForPc  *runtime.Func
}

// attaches the file and line number corresponding to
// the log message
func (l *logger) linePrefix(skipFrames int) string {
	runtime.Callers(skipFrames, l.pc)
	funcForPc := runtime.FuncForPC(l.pc[0])
	file, line := funcForPc.FileLine(l.pc[0])
	return fmt.Sprintf("%s%s:%d ", l.prefix, filepath.Base(file), line)
}

func (l *logger) print(out io.Writer, skipFrames int, severity string, arg interface{}) {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)
	buf.WriteString(severity)
	buf.WriteString(" ")
	buf.WriteString(l.linePrefix(skipFrames))
	fmt.Fprintf(buf, "%v", arg)
	ctx.PrintTo(buf)
	buf.WriteByte('\n')
	_, err := out.Write(buf.Bytes())
	if err != nil {
		errorOnLogging(err)
	}
	if l.printStack {
		l.doPrintStack()
	}
}

func (l *logger) printf(out io.Writer, skipFrames int, severity string, message string, args ...interface{}) {
	buf := bufferPool.Get()
	defer bufferPool.Put(buf)
	buf.WriteString(severity)
	buf.WriteString(" ")
	buf.WriteString(l.linePrefix(skipFrames))
	fmt.Fprintf(buf, message, args...)
	ctx.PrintTo(buf)
	buf.WriteByte('\n')
	_, err := out.Write(buf.Bytes())
	if err != nil {
		errorOnLogging(err)
	}
	if l.printStack {
		l.doPrintStack()
	}
}

func (l *logger) Debug(arg interface{}) {
	l.print(GetOutputs().DebugOut, 4, "DEBUG", arg)
}

func (l *logger) Debugf(message string, args ...interface{}) {
	l.printf(GetOutputs().DebugOut, 4, "DEBUG", message, args...)
}

func (l *logger) Error(arg interface{}) {
	l.print(GetOutputs().ErrorOut, 4, "ERROR", arg)
}

func (l *logger) Errorf(message string, args ...interface{}) {
	l.printf(GetOutputs().ErrorOut, 4, "ERROR", message, args...)
}

func (l *logger) Fatal(arg interface{}) {
	l.print(GetOutputs().ErrorOut, 4, "FATAL", arg)
	os.Exit(1)
}

func (l *logger) Fatalf(message string, args ...interface{}) {
	l.printf(GetOutputs().ErrorOut, 4, "FATAL", message, args...)
	os.Exit(1)
}

func (l *logger) Trace(arg interface{}) {
	if l.traceOn {
		l.print(GetOutputs().DebugOut, 4, "TRACE", arg)
	}
}

func (l *logger) Tracef(fmt string, args ...interface{}) {
	if l.traceOn {
		l.printf(GetOutputs().DebugOut, 4, "TRACE", fmt, args...)
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
				l.printf(GetOutputs().DebugOut, 6, "TRACE", "TraceWriter closed due to unexpected error: %v", err)
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

func (l *logger) doPrintStack() {
	var b []byte
	buf := bytes.NewBuffer(b)
	for _, pc := range l.pc {
		funcForPc := runtime.FuncForPC(pc)
		if funcForPc == nil {
			break
		}
		name := funcForPc.Name()
		if strings.HasPrefix(name, "runtime.") {
			break
		}
		file, line := funcForPc.FileLine(pc)
		fmt.Fprintf(buf, "\t%s\t%s: %d\n", name, file, line)
	}
	if _, err := buf.WriteTo(os.Stderr); err != nil {
		errorOnLogging(err)
	}
}

func errorOnLogging(err error) {
	fmt.Fprintf(os.Stderr, "Unable to log: %v\n", err)
}
