package stack_test

import (
	"fmt"

	"gopkg.in/stack.v0"
)

func Example_callFormat() {
	log("%+s")
	log("%v   %[1]n()")
	// Output:
	// gopkg.in/stack.v0/format_test.go
	// format_test.go:11   Example_callFormat()
}

func log(format string) {
	fmt.Printf(format+"\n", stack.Caller(1))
}
