// Copyright 2014 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package structs

type S struct {
	X, Y       float64
	unexported bool
}

func (s *S) Sum() float64 {
	return s.X + s.Y
}
