package otto

import (
	"fmt"
	"strings"
	"os"
)

func formatForConsole(argumentList []Value) string {
	output := []string{}
	for _, argument := range argumentList {
		output = append(output, fmt.Sprintf("%v", argument))
	}
	return strings.Join(output, " ")
}

func builtinConsole_log(call FunctionCall) Value {
	fmt.Fprintln(os.Stdout, formatForConsole(call.ArgumentList))
	return UndefinedValue()
}

func builtinConsole_error(call FunctionCall) Value {
	fmt.Fprintln(os.Stdout, formatForConsole(call.ArgumentList))
	return UndefinedValue()
}

func builtinConsole_placeholder(call FunctionCall) Value {
	// Do nothing, for now
	return UndefinedValue()
}

func (runtime *_runtime) newConsole() *_object {

	self := runtime.newObject()
	self.Define(
		"log", builtinConsole_log,
		"debug", builtinConsole_log,
		"info", builtinConsole_log,
		"error", builtinConsole_error,
		"warn", builtinConsole_error,

		"dir", builtinConsole_placeholder,
		"time", builtinConsole_placeholder,
		"timeEnd", builtinConsole_placeholder,
		"trace", builtinConsole_placeholder,
		"assert", builtinConsole_placeholder,
	)
	return self
}
