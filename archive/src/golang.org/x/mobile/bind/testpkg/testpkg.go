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

	"golang.org/x/mobile/bind/testpkg/secondpkg"
	"golang.org/x/mobile/bind/testpkg/simplepkg"
	"golang.org/x/mobile/bind/testpkg/unboundpkg"
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
	StringVar     = "a string var"
	IntVar        = 77
	StructVar     = &S{name: "a struct var"}
	InterfaceVar  I
	InterfaceVar2 I2
	NodeVar       = &Node{V: "a struct var"}
)

type Nummer interface {
	Num()
}

type I interface {
	F()

	E() error
	V() int
	VE() (int, error)
	I() I
	S() *S
	StoString(seq *S) string

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

func I2Dup(i I2) I2 {
	return i
}

func IDup(i I) I {
	return i
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

type (
	Concrete struct{}

	Interface interface {
		F()
	}
)

func (_ *Concrete) F() {
}

func NewConcrete() *Concrete {
	return new(Concrete)
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

type GoCallback interface {
	VarUpdate()
}

func CallWithCallback(gcb GoCallback) {
	for i := 0; i < 1000; i++ {
		gcb.VarUpdate()
	}
}

type NullTest interface {
	Null() NullTest
}

func NewNullInterface() I {
	return nil
}

func NewNullStruct() *S {
	return nil
}

func CallWithNull(_null NullTest, nuller NullTest) bool {
	return _null == nil && nuller.Null() == nil
}

type Issue14168 interface {
	F(seq int32)
}

func ReadIntoByteArray(s []byte) (int, error) {
	if len(s) != cap(s) {
		return 0, fmt.Errorf("cap %d != len %d", cap(s), len(s))
	}
	for i := 0; i < len(s); i++ {
		s[i] = byte(i)
	}
	return len(s), nil
}

type B interface {
	B(b []byte)
}

func PassByteArray(b B) {
	b.B([]byte{1, 2, 3, 4})
}

func GoroutineCallback(r Receiver) {
	done := make(chan struct{})
	go func() {
		// Run it multiple times to increase the chance that the goroutine
		// will use different threads for the call. Use a long argument string to
		// make sure the JNI calls take more time.
		for i := 0; i < 100000; i++ {
			r.Hello("HelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHelloHello")
		}
		close(done)
	}()
	<-done
}

func Hi() {
	fmt.Println("Hi")
}

func Int(x int32) {
	fmt.Println("Received int32", x)
}

type I2 interface {
	Times(v int32) int64
	Error(triggerError bool) error

	StringError(s string) (string, error)
}

type myI2 struct{}

func (_ *myI2) Times(v int32) int64 {
	return int64(v) * 10
}

func (_ *myI2) Error(e bool) error {
	if e {
		return errors.New("some error")
	}
	return nil
}

func (_ *myI2) StringError(s string) (string, error) {
	return s, nil
}

func CallIError(i I2, triggerError bool) error {
	return i.Error(triggerError)
}

func CallIStringError(i I2, s string) (string, error) {
	return i.StringError(s)
}

func NewI() I2 {
	return &myI2{}
}

var pinnedI = make(map[int32]I2)

func RegisterI(idx int32, i I2) {
	pinnedI[idx] = i
}

func UnregisterI(idx int32) {
	delete(pinnedI, idx)
}

func Multiply(idx int32, val int32) int64 {
	i, ok := pinnedI[idx]
	if !ok {
		panic(fmt.Sprintf("unknown I2 with index %d", idx))
	}
	return i.Times(val)
}

func AppendHello(s string) string {
	return fmt.Sprintf("Hello, %s!", s)
}

func ReturnsError(b bool) (string, error) {
	if b {
		return "", errors.New("Error")
	}
	return "OK", nil
}

var collectS2 = make(chan struct{}, 100)

func finalizeS(a *S2) {
	collectS2 <- struct{}{}
}

func CollectS2(want, timeoutSec int) int {
	runtime.GC()

	tick := time.NewTicker(time.Duration(timeoutSec) * time.Second)
	defer tick.Stop()

	for i := 0; i < want; i++ {
		select {
		case <-collectS2:
		case <-tick.C:
			fmt.Println("CollectS: timed out")
			return i
		}
	}
	return want
}

type S2 struct {
	X, Y       float64
	unexported bool
}

func NewS2(x, y float64) *S2 {
	s := &S2{X: x, Y: y}
	runtime.SetFinalizer(s, finalizeS)
	return s
}

func (_ *S2) TryTwoStrings(first, second string) string {
	return first + second
}

func (s *S2) Sum() float64 {
	return s.X + s.Y
}

func CallSSum(s *S2) float64 {
	return s.Sum()
}

// Issue #13033
type NullFieldStruct struct {
	F *S
}

func NewNullFieldStruct() *NullFieldStruct {
	return &NullFieldStruct{}
}

var (
	ImportedVarI secondpkg.I  = NewImportedI()
	ImportedVarS *secondpkg.S = NewImportedS()
)

type (
	ImportedFields struct {
		I secondpkg.I
		S *secondpkg.S
	}

	ImportedI interface {
		F(_ secondpkg.I)
	}

	AnSer struct{}
)

func (_ *AnSer) S(_ *secondpkg.S) {
}

func NewImportedFields() *ImportedFields {
	return &ImportedFields{
		I: NewImportedI(),
		S: NewImportedS(),
	}
}

func NewImportedI() secondpkg.I {
	return NewImportedS()
}

func NewImportedS() *secondpkg.S {
	return new(secondpkg.S)
}

func WithImportedI(i secondpkg.I) secondpkg.I {
	return i
}

func WithImportedS(s *secondpkg.S) *secondpkg.S {
	return s
}

func CallImportedI(i secondpkg.I) {
	i.F(0)
}

func NewSer() *AnSer {
	return nil
}

func NewSimpleS() *simplepkg.S {
	return nil
}

func UnboundS(_ *unboundpkg.S) {
}

func UnboundI(_ unboundpkg.I) {
}

type (
	InterfaceDupper interface {
		IDup(i Interface) Interface
	}

	ConcreteDupper interface {
		CDup(c *Concrete) *Concrete
	}
)

func CallIDupper(d InterfaceDupper) bool {
	var want Interface = new(Concrete)
	got := d.IDup(want)
	return got == want
}

func CallCDupper(d ConcreteDupper) bool {
	want := new(Concrete)
	got := d.CDup(want)
	return got == want
}
