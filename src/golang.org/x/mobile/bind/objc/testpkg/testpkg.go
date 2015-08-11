// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package testpkg

//go:generate gobind -lang=go -outdir=go_testpkg .
//go:generate gobind -lang=objc -outdir=objc_testpkg .

import (
	"errors"
	"fmt"
	"runtime"
	"time"
)

type I interface {
	Times(v int32) int64
}

type myI struct{}

func (i *myI) Times(v int32) int64 {
	return int64(v) * 10
}

func NewI() I {
	return &myI{}
}

var pinnedI = make(map[int32]I)

func RegisterI(idx int32, i I) {
	pinnedI[idx] = i
}

func UnregisterI(idx int32) {
	delete(pinnedI, idx)
}

func Multiply(idx int32, val int32) int64 {
	i, ok := pinnedI[idx]
	if !ok {
		panic(fmt.Sprintf("unknown I with index %d", i))
	}
	return i.Times(val)
}

func GC() {
	runtime.GC()
}

func Hi() {
	fmt.Println("Hi")
}

func Int(x int32) {
	fmt.Println("Received int32", x)
}

func Sum(x, y int64) int64 {
	return x + y
}

func Hello(s string) string {
	return fmt.Sprintf("Hello, %s!", s)
}

func BytesAppend(a []byte, b []byte) []byte {
	return append(a, b...)
}

func ReturnsError(b bool) (string, error) {
	if b {
		return "", errors.New("Error")
	}
	return "OK", nil
}

var collectS = make(chan struct{}, 100)

func finalizeS(a *S) {
	collectS <- struct{}{}
}

func CollectS(want, timeoutSec int) int {
	runtime.GC()

	tick := time.NewTicker(time.Duration(timeoutSec) * time.Second)
	defer tick.Stop()

	for i := 0; i < want; i++ {
		select {
		case <-collectS:
		case <-tick.C:
			fmt.Println("CollectS: timed out")
			return i
		}
	}
	return want
}

type S struct {
	X, Y       float64
	unexported bool
}

func NewS(x, y float64) *S {
	s := &S{X: x, Y: y}
	runtime.SetFinalizer(s, finalizeS)
	return s
}

func (s *S) TryTwoStrings(first, second string) string {
	return first + second
}

func (s *S) Sum() float64 {
	return s.X + s.Y
}

func CallSSum(s *S) float64 {
	return s.Sum()
}
