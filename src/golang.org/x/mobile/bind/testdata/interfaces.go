// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package interfaces

type I interface {
	Rand() int32
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
