// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package issue10788

type TestStruct struct {
	Value string
}

type TestInterface interface {
	DoSomeWork(s *TestStruct)
	MultipleUnnamedParams(_ int, p0 string, _ int64)
}
