// Package testpkg contains bound functions for testing the cgo-JNI interface.
package testpkg

//go:generate gobind -lang=go -output=go_testpkg/go_testpkg.go .
//go:generate gobind -lang=java -output=Testpkg.java .
import (
	"errors"
	"fmt"
	"runtime"
	"time"
)

type I interface {
	F()

	E() error
	V() int
	VE() (int, error)
	I() I
	S() *S

	String() string
}

func CallF(i I) {
	i.F()
}

func CallE(i I) error {
	return i.E()
}

func CallV(i I) int {
	return i.V()
}

func CallVE(i I) (int, error) {
	return i.VE()
}

func CallI(i I) I {
	return i
}

func CallS(i I) *S {
	return &S{}
}

var keep []I

func Keep(i I) {
	keep = append(keep, i)
}

var numSCollected int

type S struct {
	// *S already has a finalizer, so we need another object
	// to count successful collections.
	innerObj *int

	name string
}

func (s *S) F() {
	fmt.Printf("called F on *S{%s}\n", s.name)
}

func (s *S) String() string {
	return s.name
}

func finalizeInner(*int) {
	numSCollected++
}

func New() *S {
	s := &S{innerObj: new(int), name: "new"}
	runtime.SetFinalizer(s.innerObj, finalizeInner)
	return s
}

func GC() {
	runtime.GC()
	time.Sleep(10 * time.Millisecond)
	runtime.GC()
}

func Add(x, y int) int {
	return x + y
}

func NumSCollected() int {
	return numSCollected
}

func StrDup(s string) string {
	return s
}

func Err(s string) error {
	if s != "" {
		return errors.New(s)
	}
	return nil
}

func BytesAppend(a []byte, b []byte) []byte {
	return append(a, b...)
}

func AppendToString(str string, someBytes []byte) []byte {
	a := []byte(str)
	fmt.Printf("str=%q (len=%d), someBytes=%v (len=%d)\n", str, len(str), someBytes, len(someBytes))
	return append(a, someBytes...)
}
