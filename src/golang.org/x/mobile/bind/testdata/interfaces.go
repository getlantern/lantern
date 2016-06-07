// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package interfaces

type I interface {
	Rand() int32
}

type SameI interface {
	Rand() int32
}

type LargerI interface {
	Rand() int32
	AnotherFunc()
}

func Add3(r I) int32 {
	return r.Rand() + r.Rand() + r.Rand()
}

// chosen by fair dice roll.
// guaranteed to be random.
type seven struct{}

func (seven) Rand() int32 { return 7 }

func Seven() I { return seven{} }

type WithParam interface {
	HasParam(p bool)
}

type Error interface {
	Err() error
}

func CallErr(e Error) error {
	return e.Err()
}

// not implementable
type I1 interface {
	J()
	H() *seven // not bound
}

// not implementable
type I2 interface {
	f()
	G()
}

// implementable
// (the implementor has to find a source of I1s)
type I3 interface {
	F() I1
}

// not bound
func F() seven  { return seven{} }
func G(u seven) {}
