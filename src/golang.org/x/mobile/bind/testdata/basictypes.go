// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package basictypes

func Ints(x int8, y int16, z int32, t int64, u int) {}

func Error() error { return nil }

func ErrorPair() (int, error) { return 0, nil }

func ByteArrays(x []byte) []byte { return nil }

func Bool(bool) bool { return true }
