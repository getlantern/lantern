// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package testpkg

//go:generate gobind -lang=go -outdir=go_testpkg .

import "fmt"

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
