// Test for pointless make() calls.

// Package pkg ...
package pkg

import "net/http"

// T is a test type.
type T int

var z []T

func f() {
	x := make([]T, 0)            // MATCH /var x \[\]T/
	y := make([]http.Request, 0) // MATCH /var y \[\]http\.Request/
	z = make([]T, 0)             // ok, because we don't know where z is declared

	_, _ = x, y
}
