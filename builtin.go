package otto

import (
	"encoding/hex"
	"fmt"
	"math"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

// Global
func builtinGlobal_eval(call FunctionCall) Value {
	source := call.Argument(0)
	if !source.IsString() {
		return source
	}
	program, err := parse(toString(source))
	if err != nil {
		switch err := err.(type) {
		case *_syntaxError, *_error, _error:
			panic(err)
		default:
			panic(&_syntaxError{Message: fmt.Sprintf("%v", err)})
		}
	}
	runtime := call.runtime
	if call.evalHint {
		runtime.EnterEvalExecutionContext(call)
		defer runtime.LeaveExecutionContext()
	}
	returnValue := runtime.evaluate(program)
	if returnValue.isEmpty() {
		return UndefinedValue()
	}
	return returnValue
}

func builtinGlobal_isNaN(call FunctionCall) Value {
	value := toFloat(call.Argument(0))
	return toValue(math.IsNaN(value))
}

func builtinGlobal_isFinite(call FunctionCall) Value {
	value := toFloat(call.Argument(0))
	return toValue(!math.IsNaN(value) && !math.IsInf(value, 0))
}

func builtinGlobal_parseInt(call FunctionCall) Value {
	// Caveat emptor: This implementation does NOT match the specification
	string_ := strings.TrimSpace(toString(call.Argument(0)))
	radix := call.Argument(1)
	radixValue := 0
	if radix.IsDefined() {
		radixValue = int(toInt32(radix))
	}
	value, err := strconv.ParseInt(string_, radixValue, 64)
	if err != nil {
		return NaNValue()
	}
	return toValue(value)
}

func builtinGlobal_parseFloat(call FunctionCall) Value {
	// Caveat emptor: This implementation does NOT match the specification
	string_ := strings.TrimSpace(toString(call.Argument(0)))
	value, err := strconv.ParseFloat(string_, 64)
	if err != nil {
		return NaNValue()
	}
	return toValue(value)
}

// encodeURI/decodeURI

func _builtinGlobal_encodeURI(call FunctionCall, characterRegexp *regexp.Regexp) Value {
	value := []byte(toString(call.Argument(0)))
	value = characterRegexp.ReplaceAllFunc(value, func(target []byte) []byte {
		// Probably a better way of doing this
		if target[0] == ' ' {
			return []byte("%20")
		}
		return []byte(url.QueryEscape(string(target)))
	})
	return toValue(string(value))
}

var encodeURI_Regexp = regexp.MustCompile(`([^~!@#$&*()=:/,;?+'])`)

func builtinGlobal_encodeURI(call FunctionCall) Value {
	return _builtinGlobal_encodeURI(call, encodeURI_Regexp)
}

var encodeURIComponent_Regexp = regexp.MustCompile(`([^~!*()'])`)

func builtinGlobal_encodeURIComponent(call FunctionCall) Value {
	return _builtinGlobal_encodeURI(call, encodeURIComponent_Regexp)
}

func builtinGlobal_decodeURI_decodeURIComponent(call FunctionCall) Value {
	value, err := url.QueryUnescape(toString(call.Argument(0)))
	if err != nil {
		panic(newURIError("URI malformed"))
	}
	return toValue(value)
}

// escape/unescape

func builtin_shouldEscape(chr byte) bool {
	if 'A' <= chr && chr <= 'Z' || 'a' <= chr && chr <= 'z' || '0' <= chr && chr <= '9' {
		return false
	}
	return !strings.ContainsRune("*_+-./", rune(chr))
}

const escapeBase16 = "0123456789ABCDEF"

func builtin_escape(input string) string {
	output := make([]byte, 0, len(input))
	length := len(input)
	for index := 0; index < length; {
		if builtin_shouldEscape(input[index]) {
			chr, width := utf8.DecodeRuneInString(input[index:])
			chr16 := utf16.Encode([]rune{chr})[0]
			if 256 > chr16 {
				output = append(output, '%',
					escapeBase16[chr16>>4],
					escapeBase16[chr16&15],
				)
			} else {
				output = append(output, '%', 'u',
					escapeBase16[chr16>>12],
					escapeBase16[(chr16>>8)&15],
					escapeBase16[(chr16>>4)&15],
					escapeBase16[chr16&15],
				)
			}
			index += width

		} else {
			output = append(output, input[index])
			index += 1
		}
	}
	return string(output)
}

func builtin_unescape(input string) string {
	output := make([]rune, 0, len(input))
	length := len(input)
	for index := 0; index < length; {
		if input[index] == '%' {
			if index <= length-6 && input[index+1] == 'u' {
				byte16, err := hex.DecodeString(input[index+2 : index+6])
				if err == nil {
					value := uint16(byte16[0])<<8 + uint16(byte16[1])
					chr := utf16.Decode([]uint16{value})[0]
					output = append(output, chr)
					index += 6
					continue
				}
			}
			if index <= length-3 {
				byte8, err := hex.DecodeString(input[index+1 : index+3])
				if err == nil {
					value := uint16(byte8[0])
					chr := utf16.Decode([]uint16{value})[0]
					output = append(output, chr)
					index += 3
					continue
				}
			}
		}
		output = append(output, rune(input[index]))
		index += 1
	}
	return string(output)
}

func builtinGlobal_escape(call FunctionCall) Value {
	return toValue(builtin_escape(toString(call.Argument(0))))
}

func builtinGlobal_unescape(call FunctionCall) Value {
	return toValue(builtin_unescape(toString(call.Argument(0))))
}

// Error

func builtinError(call FunctionCall) Value {
	return toValue(call.runtime.newError("", call.Argument(0)))
}

func builtinNewError(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newError("", valueOfArrayIndex(argumentList, 0)))
}

func builtinError_toString(call FunctionCall) Value {
	thisObject := call.thisObject()
	if thisObject == nil {
		panic(newTypeError())
	}

	name := "Error"
	nameValue := thisObject.get("name")
	if nameValue.IsDefined() {
		name = toString(nameValue)
	}

	message := ""
	messageValue := thisObject.get("message")
	if messageValue.IsDefined() {
		message = toString(messageValue)
	}

	if len(name) == 0 {
		return toValue(message)
	}

	if len(message) == 0 {
		return toValue(name)
	}

	return toValue(fmt.Sprintf("%s: %s", name, message))
}
