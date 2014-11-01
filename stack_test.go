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

func (tt testType) testMethod() (pc uintptr, file string, line int, ok bool) {
	return runtime.Caller(0)
}

func TestCallFormat(t *testing.T) {
	t.Parallel()

	pc, file, line, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("runtime.Caller(0) failed")
	}

	gopathSrc := filepath.Join(os.Getenv("GOPATH"), "src")
	relFile, err := filepath.Rel(gopathSrc, file)
	if err != nil {
		t.Fatalf("failed to determine path relative to GOPATH: %v", err)
	}
	relFile = filepath.ToSlash(relFile)

	pc2, file2, line2, ok2 := testType{}.testMethod()
	if !ok2 {
		t.Fatal("runtime.Caller(0) failed")
	}
	relFile2, err := filepath.Rel(gopathSrc, file)
	if err != nil {
		t.Fatalf("failed to determine path relative to GOPATH: %v", err)
	}
	relFile2 = filepath.ToSlash(relFile2)

	data := []struct {
		pc   uintptr
		desc string
		fmt  string
		out  string
	}{
		{0, "error", "%s", "%!s(NOFUNC)"},

		{pc, "func", "%s", path.Base(file)},
		{pc, "func", "%+s", relFile},
		{pc, "func", "%#s", file},
		{pc, "func", "%d", fmt.Sprint(line)},
		{pc, "func", "%n", "TestCallFormat"},
		{pc, "func", "%+n", runtime.FuncForPC(pc).Name()},
		{pc, "func", "%v", fmt.Sprint(path.Base(file), ":", line)},
		{pc, "func", "%+v", fmt.Sprint(relFile, ":", line)},
		{pc, "func", "%#v", fmt.Sprint(file, ":", line)},
		{pc, "func", "%v|%[1]n()", fmt.Sprint(path.Base(file), ":", line, "|", "TestCallFormat()")},

		{pc2, "meth", "%s", path.Base(file2)},
		{pc2, "meth", "%+s", relFile2},
		{pc2, "meth", "%#s", file2},
		{pc2, "meth", "%d", fmt.Sprint(line2)},
		{pc2, "meth", "%n", "testType.testMethod"},
		{pc2, "meth", "%+n", runtime.FuncForPC(pc2).Name()},
		{pc2, "meth", "%v", fmt.Sprint(path.Base(file2), ":", line2)},
		{pc2, "meth", "%+v", fmt.Sprint(relFile2, ":", line2)},
		{pc2, "meth", "%#v", fmt.Sprint(file2, ":", line2)},
		{pc2, "meth", "%v|%[1]n()", fmt.Sprint(path.Base(file2), ":", line2, "|", "testType.testMethod()")},
	}

	for _, d := range data {
		got := fmt.Sprintf(d.fmt, stack.Call(d.pc))
		if got != d.out {
			t.Errorf("fmt.Sprintf(%q, Call(%s)) = %s, want %s", d.fmt, d.desc, got, d.out)
		}
	}
}

func BenchmarkCallVFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprint(ioutil.Discard, stack.Call(pc))
	}
}

func BenchmarkCallPlusVFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+v", stack.Call(pc))
	}
}

func BenchmarkCallSharpVFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%#v", stack.Call(pc))
	}
}

func BenchmarkCallSFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%s", stack.Call(pc))
	}
}

func BenchmarkCallPlusSFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+s", stack.Call(pc))
	}
}

func BenchmarkCallSharpSFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%#s", stack.Call(pc))
	}
}

func BenchmarkCallDFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%d", stack.Call(pc))
	}
}

func BenchmarkCallNFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%n", stack.Call(pc))
	}
}

func BenchmarkCallPlusNFmt(b *testing.B) {
	pc, _, _, ok := runtime.Caller(0)
	if !ok {
		b.Fatal("runtime.Caller(0) failed")
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		fmt.Fprintf(ioutil.Discard, "%+n", stack.Call(pc))
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
