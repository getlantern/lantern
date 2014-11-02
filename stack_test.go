package stack_test

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/go-stack/stack"
)

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

	gopathSrc := filepath.Join(os.Getenv("GOPATH"), "src")
	relFile, err := filepath.Rel(gopathSrc, file)
	if err != nil {
		t.Fatalf("failed to determine path relative to GOPATH: %v", err)
	}
	relFile = filepath.ToSlash(relFile)

	c2, pc2, file2, line2, ok2 := testType{}.testMethod()
	if !ok2 {
		t.Fatal("runtime.Caller(0) failed")
	}
	relFile2, err := filepath.Rel(gopathSrc, file)
	if err != nil {
		t.Fatalf("failed to determine path relative to GOPATH: %v", err)
	}
	relFile2 = filepath.ToSlash(relFile2)

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
		{c, "func", "%v|%[1]n()", fmt.Sprint(path.Base(file), ":", line, "|", "TestCallFormat()")},

		{c2, "meth", "%s", path.Base(file2)},
		{c2, "meth", "%+s", relFile2},
		{c2, "meth", "%#s", file2},
		{c2, "meth", "%d", fmt.Sprint(line2)},
		{c2, "meth", "%n", "testType.testMethod"},
		{c2, "meth", "%+n", runtime.FuncForPC(pc2).Name()},
		{c2, "meth", "%v", fmt.Sprint(path.Base(file2), ":", line2)},
		{c2, "meth", "%+v", fmt.Sprint(relFile2, ":", line2)},
		{c2, "meth", "%#v", fmt.Sprint(file2, ":", line2)},
		{c2, "meth", "%v|%[1]n()", fmt.Sprint(path.Base(file2), ":", line2, "|", "testType.testMethod()")},
	}

	for _, d := range data {
		got := fmt.Sprintf(d.fmt, d.c)
		if got != d.out {
			t.Errorf("fmt.Sprintf(%q, Call(%s)) = %s, want %s", d.fmt, d.desc, got, d.out)
		}
	}
}

func BenchmarkCallVFmt(b *testing.B) {
	c := stack.Caller(0)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprint(ioutil.Discard, c)
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

func BenchmarkTrace(b *testing.B) {
	for i := 0; i < b.N; i++ {
		stack.Trace()
	}
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
