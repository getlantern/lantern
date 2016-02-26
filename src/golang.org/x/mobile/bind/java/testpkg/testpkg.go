// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

// Package testpkg contains bound functions for testing the cgo-JNI interface.
// This is used in tests of golang.org/x/mobile/bind/java.
package testpkg

//go:generate gobind -lang=go -outdir=go_testpkg .
//go:generate gobind -lang=java -outdir=. .
import (
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"math"
	"runtime"
	"time"

	"golang.org/x/mobile/asset"
)

const (
	AString = "a string"
	AnInt   = 7
	ABool   = true
	AFloat  = 0.12345

	MinInt32               int32   = math.MinInt32
	MaxInt32               int32   = math.MaxInt32
	MinInt64                       = math.MinInt64
	MaxInt64                       = math.MaxInt64
	SmallestNonzeroFloat64         = math.SmallestNonzeroFloat64
	MaxFloat64                     = math.MaxFloat64
	SmallestNonzeroFloat32 float32 = math.SmallestNonzeroFloat64
	MaxFloat32             float32 = math.MaxFloat32
	Log2E                          = math.Log2E
)

var (
	StringVar    = "a string var"
	IntVar       = 77
	StructVar    = &S{name: "a struct var"}
	InterfaceVar I
)

type I interface {
	F()

	E() error
	V() int
	VE() (int, error)
	I() I
	S() *S
	StoString(*S) string

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

func finalizeInner(a *int) {
	numSCollected++
}

var seq = 0

func New() *S {
	s := &S{innerObj: new(int), name: fmt.Sprintf("new%d", seq)}
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

func Negate(x bool) bool {
	return !x
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

func UnnamedParams(_, _ int, p0 string) int {
	return len(p0)
}

type Node struct {
	V    string
	Next *Node
	Err  error
}

func NewNode(name string) *Node {
	return &Node{V: name}
}

func (a *Node) String() string {
	if a == nil {
		return "<end>"
	}
	return a.V + ":" + a.Next.String()
}

type Receiver interface {
	Hello(message string)
}

func Hello(r Receiver, name string) {
	r.Hello(fmt.Sprintf("Hello, %s!\n", name))
}

func GarbageCollect() {
	runtime.GC()
}

func ReadAsset() string {
	rc, err := asset.Open("hello.txt")
	if err != nil {
		log.Fatal(err)
	}
	defer rc.Close()

	b, err := ioutil.ReadAll(rc)
	if err != nil {
		log.Fatal(err)
	}
	return string(b)
}
