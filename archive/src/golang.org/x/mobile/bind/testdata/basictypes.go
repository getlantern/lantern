// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package basictypes

const (
	AString     = "a string"
	AnInt       = 7
	AnInt2      = 1<<63 - 1
	AFloat      = 0.2015
	ARune       = rune(32)
	ABool       = true
	ALongString = "LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString,LongString"
)

func Ints(x int8, y int16, z int32, t int64, u int) {}

func Error() error { return nil }

func ErrorPair() (int, error) { return 0, nil }

func ByteArrays(x []byte) []byte { return nil }

func Bool(bool) bool { return true }
