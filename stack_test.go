package stack_test

import (
	"fmt"
	"io/ioutil"
	"path"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/go-stack/stack"
)

const importPath = "github.com/go-stack/stack"

type testType struct{}

func (tt testType) testMethod() (c stack.Call, pc uintptr, file string, line int, ok bool) {
	c = stack.Caller(0)
	pc, file, line, ok = runtime.Caller(0)
	line--
	return
}

func TestCallFormat(t *testing.T) {
	t.Parallel()

	c := stack.Caller(0)
	pc, file, line, ok := runtime.Caller(0)
	line--
	if !ok {
		t.Fatal("runtime.Caller(0) failed")
	}
	relFile := path.Join(importPath, filepath.Base(file))

	c2, pc2, file2, line2, ok2 := testType{}.testMethod()
	if !ok2 {
		t.Fatal("runtime.Caller(0) failed")
	}
	relFile2 := path.Join(importPath, filepath.Base(file2))

	data := []struct {
		c    stack.Call
		desc string
		fmt  string
		out  string
	}{
		{stack.Call{}, "error", "%s", "%!s(NOFUNC)"},

		{c, "func", "%s", path.Base(file)},
		{c, "func", "%+s", relFile},
		{c, "func", "%#s", file},
		{c, "func", "%d", fmt.Sprint(line)},
		{c, "func", "%n", "TestCallFormat"},
		{c, "func", "%+n", runtime.FuncForPC(pc - 1).Name()},
		{c, "func", "%v", fmt.Sprint(path.Base(file), ":", line)},
		{c, "func", "%+v", fmt.Sprint(relFile, ":", line)},
		{c, "func", "%#v", fmt.Sprint(file, ":", line)},

		{c2, "meth", "%s", path.Base(file2)},
		{c2, "meth", "%+s", relFile2},
		{c2, "meth", "%#s", file2},
		{c2, "meth", "%d", fmt.Sprint(line2)},
		{c2, "meth", "%n", "testType.testMethod"},
		{c2, "meth", "%+n", runtime.FuncForPC(pc2).Name()},
		{c2, "meth", "%v", fmt.Sprint(path.Base(file2), ":", line2)},
		{c2, "meth", "%+v", fmt.Sprint(relFile2, ":", line2)},
		{c2, "meth", "%#v", fmt.Sprint(file2, ":", line2)},
	}

	for _, d := range data {
		got := fmt.Sprintf(d.fmt, d.c)
		if got != d.out {
			t.Errorf("fmt.Sprintf(%q, Call(%s)) = %s, want %s", d.fmt, d.desc, got, d.out)
		}
	}
}

func TestTrimAbove(t *testing.T) {
	trace := trimAbove()
	if got, want := len(trace), 2; got != want {
		t.Errorf("got len(trace) == %v, want %v, trace: %n", got, want, trace)
	}
	if got, want := fmt.Sprintf("%n", trace[1]), "TestTrimAbove"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func trimAbove() stack.CallStack {
	call := stack.Caller(1)
	trace := stack.Trace()
	return trace.TrimAbove(call)
}

func TestTrimBelow(t *testing.T) {
	trace := trimBelow()
	if got, want := fmt.Sprintf("%n", trace[0]), "TestTrimBelow"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func trimBelow() stack.CallStack {
	call := stack.Caller(1)
	trace := stack.Trace()
	return trace.TrimBelow(call)
}

func TestTrimRuntime(t *testing.T) {
	trace := stack.Trace().TrimRuntime()
	if got, want := len(trace), 1; got != want {
		t.Errorf("got len(trace) == %v, want %v, trace: %#v", got, want, trace)
	}
}

func BenchmarkCallVFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprint(ioutil.Discard, c)
	}
}

func BenchmarkCallerAndVFmt(b *testing.B) {
	for i := 0; i < b.N; i++ {
		fmt.Fprint(ioutil.Discard, stack.Caller(0))
	}
}

func BenchmarkCallPlusVFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+v", c)
	}
}

func BenchmarkCallSharpVFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%#v", c)
	}
}

func BenchmarkCallSFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%s", c)
	}
}

func BenchmarkCallPlusSFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+s", c)
	}
}

func BenchmarkCallSharpSFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%#s", c)
	}
}

func BenchmarkCallDFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%d", c)
	}
}

func BenchmarkCallNFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%n", c)
	}
}

func BenchmarkCallPlusNFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+n", c)
	}
}

func BenchmarkCaller(b *testing.B) {
	for i := 0; i < b.N; i++ {
		stack.Caller(0)
	}
}

func BenchmarkTrace(b *testing.B) {
	for i := 0; i < b.N; i++ {
		stack.Trace()
	}
}

func BenchmarkFuncForPC(b *testing.B) {
	pc, _, _, _ := runtime.Caller(0)
	pc--
	var fn *runtime.Func
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fn = runtime.FuncForPC(pc)
	}
	b.StopTimer()
	fmt.Fprint(ioutil.Discard, fn.Entry())
}

func deepStack(depth int, b *testing.B) stack.CallStack {
	if depth > 0 {
		return deepStack(depth-1, b)
	}
	b.StartTimer()
	s := stack.Trace()
	b.StopTimer()
	return s
}

func BenchmarkTrace10(b *testing.B) {
	b.StopTimer()
	for i := 0; i < b.N; i++ {
		deepStack(10, b)
	}
}

func BenchmarkTrace50(b *testing.B) {
	b.StopTimer()
	for i := 0; i < b.N; i++ {
		deepStack(50, b)
	}
}

func BenchmarkTrace100(b *testing.B) {
	b.StopTimer()
	for i := 0; i < b.N; i++ {
		deepStack(100, b)
	}
}
