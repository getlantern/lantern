// Copyright 2013 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This file contains tests for the shadowed variable checker.
// Some of these errors are caught by the compiler (shadowed return parameters for example)
// but are nonetheless useful tests.

package testdata

import "os"

func ShadowRead(f *os.File, buf []byte) (err error) {
	var x int
	if f != nil {
		err := 3 // OK - different type.
		_ = err
	}
	if f != nil {
		_, err := f.Read(buf) // ERROR "declaration of err shadows declaration at testdata/shadow.go:13"
		if err != nil {
			return err
		}
		i := 3 // OK
		_ = i
	}
	if f != nil {
		var _, err = f.Read(buf) // ERROR "declaration of err shadows declaration at testdata/shadow.go:13"
		if err != nil {
			return err
		}
	}
	for i := 0; i < 10; i++ {
		i := i // OK: obviously intentional idiomatic redeclaration
		go func() {
			println(i)
		}()
	}
	var shadowTemp interface{}
	switch shadowTemp := shadowTemp.(type) { // OK: obviously intentional idiomatic redeclaration
	case int:
		println("OK")
		_ = shadowTemp
	}
	if shadowTemp := shadowTemp; true { // OK: obviously intentional idiomatic redeclaration
		var f *os.File // OK because f is not mentioned later in the function.
		// The declaration of x is a shadow because x is mentioned below.
		var x int // ERROR "declaration of x shadows declaration at testdata/shadow.go:14"
		_, _, _ = x, f, shadowTemp
	}
	// Use a couple of variables to trigger shadowing errors.
	_, _ = err, x
	return
}
