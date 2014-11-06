package stack_test

import (
	"fmt"

	"github.com/go-stack/stack"
)

func Example_callFormat() {
	log("%+s")
	log("%v   %[1]n()")
	// Output:
	// github.com/go-stack/stack/format_test.go
	// format_test.go:11   Example_callFormat()
}

func log(format string) {
	fmt.Printf(format+"\n", stack.Caller(1))
}
