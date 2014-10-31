// Package stack implements utilities to capture, manipulate, and format call
// stacks.
package stack

import (
	"fmt"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
)

// Call records a single function invocation from a goroutine stack. It is a
// wrapper for the program counter values returned by runtime.Caller and
// runtime.Callers and consumed by runtime.FuncForPC.
type Call uintptr

// Format implements fmt.Formatter with support for the following verbs.
//
//    %s    source file
//    %d    line number
//    %n    function name
//    %v    equivalent to %s:%d
//
// It accepts the '+' and '#' flags for most of the verbs as follows.
//
//    %+s   path of source file relative to the compile time GOPATH
//    %#s   full path of source file
//    %+n   import path qualified function name
//    %+v   equivalent to %+s:%d
//    %#v   equivalent to %#s:%d
func (pc Call) Format(s fmt.State, c rune) {
	// BUG(ChrisHines): Subtracting one from pc is a work around for
	// https://code.google.com/p/go/issues/detail?id=7690. The idea for this
	// work around comes from rsc's initial patch at
	// https://codereview.appspot.com/84100043/#ps20001, but as noted in the
	// issue discussion, it is not a complete fix since it doesn't handle some
	// cases involving signals. Just the same, it handles all of the other
	// cases I have tested.
	pcFix := uintptr(pc) - 1
	fn := runtime.FuncForPC(pcFix)
	if fn == nil {
		fmt.Fprintf(s, "%%!%c(NOFUNC)", c)
		return
	}

	switch c {
	case 's', 'v':
		file, line := fn.FileLine(pcFix)
		switch {
		case s.Flag('#'):
			// done
		case s.Flag('+'):
			// Here we want to get the source file path relative to the
			// compile time GOPATH. As of Go 1.3.x there is no direct way to
			// know the compiled GOPATH at runtime, but we can infer the
			// number of path segments in the GOPATH. We note that fn.Name()
			// returns the function name qualified by the import path, which
			// does not include the GOPATH. Thus we can trim segments from the
			// beginning of the file path until the number of path separators
			// remaining is one more than the number of path separators in the
			// function name. For example, given:
			//
			//    GOPATH     /home/user
			//    file       /home/user/src/pkg/sub/file.go
			//    fn.Name()  pkg/sub.Type.Method
			//
			// We want to produce:
			//
			//    pkg/sub/file.go
			//
			// From this we can easily see that fn.Name() has one less path
			// separator than our desired output.
			const sep = "/"
			impCnt := strings.Count(fn.Name(), sep) + 1
			pathCnt := strings.Count(file, sep)
			for pathCnt > impCnt {
				i := strings.Index(file, sep)
				if i == -1 {
					break
				}
				file = file[i+len(sep):]
				pathCnt--
			}
		default:
			const sep = "/"
			if i := strings.LastIndex(file, sep); i != -1 {
				file = file[i+len(sep):]
			}
		}
		fmt.Fprint(s, file)
		if c == 'v' {
			fmt.Fprint(s, ":", line)
		}

	case 'd':
		_, line := fn.FileLine(pcFix)
		fmt.Fprint(s, line)

	case 'n':
		name := fn.Name()
		if !s.Flag('+') {
			const pathSep = "/"
			if i := strings.LastIndex(name, pathSep); i != -1 {
				name = name[i+len(pathSep):]
			}
			const pkgSep = "."
			if i := strings.Index(name, pkgSep); i != -1 {
				name = name[i+len(pkgSep):]
			}
		}
		fmt.Fprint(s, name)
	}
}

// name returns the import path qualified name of the function containing the
// call.
func (pc Call) name() string {
	pcFix := uintptr(pc) - 1 // work around for go issue #7690
	fn := runtime.FuncForPC(pcFix)
	if fn == nil {
		return "???"
	}
	return fn.Name()
}

func (pc Call) file() string {
	pcFix := uintptr(pc) - 1 // work around for go issue #7690
	fn := runtime.FuncForPC(pcFix)
	if fn == nil {
		return "???"
	}
	file, _ := fn.FileLine(pcFix)
	return file
}

// Trace records a sequence of function invocations from a goroutine stack.
type Trace []Call

// Format implements fmt.Formatter by printing the Trace as square brackes ([,
// ]) surrounding a space separated list of Calls each formatted with the
// supplied verb and options.
func (pcs Trace) Format(s fmt.State, c rune) {
	s.Write([]byte("["))
	for i, pc := range pcs {
		if i > 0 {
			s.Write([]byte(" "))
		}
		pc.Format(s, c)
	}
	s.Write([]byte("]"))
}

var pcStackPool = sync.Pool{
	New: func() interface{} { return make([]uintptr, 1000) },
}

// Callers returns a Trace for the current goroutine with element 0
// identifying the calling function.
func Callers() Trace {
	pcs := pcStackPool.Get().([]uintptr)
	pcs = pcs[:cap(pcs)]
	n := runtime.Callers(2, pcs)
	cs := make([]Call, n)
	for i, pc := range pcs[:n] {
		cs[i] = Call(pc)
	}
	pcStackPool.Put(pcs)
	return cs
}

// TrimBelow returns a slice of the Trace with all entries below pc removed.
func (pcs Trace) TrimBelow(pc Call) Trace {
	for len(pcs) > 0 && pcs[0] != pc {
		pcs = pcs[1:]
	}
	return pcs
}

// TrimAbove returns a slice of the Trace with all entries above pc removed.
func (pcs Trace) TrimAbove(pc Call) Trace {
	for len(pcs) > 0 && pcs[len(pcs)-1] != pc {
		pcs = pcs[:len(pcs)-1]
	}
	return pcs
}

// TrimBelowName returns a slice of the Trace with all entries below the
// lowest with function name name removed.
func (pcs Trace) TrimBelowName(name string) Trace {
	for len(pcs) > 0 && pcs[0].name() != name {
		pcs = pcs[1:]
	}
	return pcs
}

// TrimAboveName returns a slice of the Trace with all entries above the
// highest with function name name removed.
func (pcs Trace) TrimAboveName(name string) Trace {
	for len(pcs) > 0 && pcs[len(pcs)-1].name() != name {
		pcs = pcs[:len(pcs)-1]
	}
	return pcs
}

var goroot string

func init() {
	goroot = filepath.ToSlash(runtime.GOROOT())
	if runtime.GOOS == "windows" {
		goroot = strings.ToLower(goroot)
	}
}

func inGoroot(path string) bool {
	if runtime.GOOS == "windows" {
		path = strings.ToLower(path)
	}
	return strings.HasPrefix(path, goroot)
}

// TrimRuntime returns a slice of the Trace with the topmost entries from the
// go runtime removed. It considers any calls originating from files under
// GOROOT as part of the runtime.
func (pcs Trace) TrimRuntime() Trace {
	for len(pcs) > 0 && inGoroot(pcs[len(pcs)-1].file()) {
		pcs = pcs[:len(pcs)-1]
	}
	return pcs
}
