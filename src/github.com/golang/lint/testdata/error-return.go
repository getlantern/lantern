// Test for returning errors.

// Package foo ...
package foo

// Returns nothing
func f() { // ok
}

// Check for a single error return
func g() error { // ok
	return nil
}

// Check for a single other return type
func h() int { // ok
	return 0
}

// Check for multiple return but error at end.
func i() (int, error) { // ok
	return 0, nil
}

// Check for multiple return but error at end with named variables.
func j() (x int, err error) { // ok
	return 0, nil
}

// Check for error in the wrong location on 2 types
func k() (error, int) { // MATCH /error should be the last type/
	return nil, 0
}

// Check for error in the wrong location for > 2 types
func l() (int, error, int) { // MATCH /error should be the last type/
	return 0, nil, 0
}

// Check for error in the wrong location with named variables.
func m() (x int, err error, y int) { // MATCH /error should be the last type/
	return 0, nil, 0
}
