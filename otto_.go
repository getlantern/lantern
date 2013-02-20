package otto

import (
	"fmt"
	"math"
	"regexp"
	runtime_ "runtime"
	"strconv"
	"strings"
)

var isIdentifier_Regexp *regexp.Regexp = regexp.MustCompile(`^[a-zA-Z\$][a-zA-Z0-9\$]*$`)

func isIdentifier(string_ string) bool {
	return isIdentifier_Regexp.MatchString(string_)
}

func (self *_runtime) toValueArray(arguments ...interface{}) []Value {
	length := len(arguments)
	if length == 1 {
		if valueArray, ok := arguments[0].([]Value); ok {
			return valueArray
		}
		return []Value{toValue(arguments[0])}
	}

	valueArray := make([]Value, length)
	for index, value := range arguments {
		valueArray[index] = toValue(value)
	}

	return valueArray
}

func stringToArrayIndex(name string) int64 {
	index, err := strconv.ParseInt(name, 10, 64)
	if err != nil {
		return -1
	}
	if index < 0 {
		return -1
	}
	if index > integer_2_32 {
		return -1 // Bigger than an unsigned 32-bit integer
	}
	return index
}

func arrayIndexToString(index uint) string {
	return strconv.FormatInt(int64(index), 10)
}

func valueOfArrayIndex(list []Value, index int) Value {
	if index >= 0 && index < len(list) {
		value := list[index]
		if !value.isEmpty() {
			return value
		}
	}
	return UndefinedValue()
}

// A range index can be anything from 0 up to length. It is NOT safe to use as an index
// to an array, but is useful for slicing and in some ECMA algorithms.
func valueToRangeIndex(indexValue Value, length uint, negativeIsZero bool) uint {
	index := toIntegerFloat(indexValue)
	if negativeIsZero {
		index := uint(math.Max(index, 0))
		// minimum(index, length)
		if index >= length {
			return length
		}
		return index
	}

	if index < 0 {
		index = math.Max(index+float64(length), 0)
	} else {
		index = math.Min(index, float64(length))
	}
	return uint(index)
}

func rangeStartEnd(array []Value, size uint, negativeIsZero bool) (start, end uint) {
	start = valueToRangeIndex(valueOfArrayIndex(array, 0), size, negativeIsZero)
	if len(array) == 1 {
		// If there is only the start argument, then end = size
		end = size
		return
	}

	// Assuming the argument is undefined...
	end = size
	endValue := valueOfArrayIndex(array, 1)
	if !endValue.IsUndefined() {
		// Which it is not, so get the value as an array index
		end = valueToRangeIndex(endValue, size, negativeIsZero)
	}
	return
}

func rangeStartLength(source []Value, size uint) (start, length int64) {
	start = int64(valueToRangeIndex(valueOfArrayIndex(source, 0), size, false))

	// Assume the second argument is missing or undefined
	length = int64(size)
	if len(source) == 1 {
		// If there is only the start argument, then length = size
		return
	}

	lengthValue := valueOfArrayIndex(source, 1)
	if !lengthValue.IsUndefined() {
		// Which it is not, so get the value as an array index
		length = toInteger(lengthValue)
	}
	return
}

func boolFields(input string) (result map[string]bool) {
	result = map[string]bool{}
	for _, word := range strings.Fields(input) {
		result[word] = true
	}
	return result
}

func hereBeDragons(arguments ...interface{}) string {
	pc, _, _, _ := runtime_.Caller(1)
	name := runtime_.FuncForPC(pc).Name()
	message := fmt.Sprintf("Here be dragons -- %s", name)
	if len(arguments) > 0 {
		message += ": "
		argument0 := fmt.Sprintf("%s", arguments[0])
		if len(arguments) == 1 {
			message += argument0
		} else {
			message += fmt.Sprintf(argument0, arguments[1:]...)
		}
	} else {
		message += "."
	}
	return message
}

func throwHereBeDragons(arguments ...interface{}) {
	panic(hereBeDragons(arguments...))
}

func eachPair(list []interface{}, fn func(_0, _1 interface{})) {
	for len(list) > 0 {
		var _0, _1 interface{}
		_0 = list[0]
		list = list[1:] // Pop off first
		if len(list) > 0 {
			_1 = list[0]
			list = list[1:] // Pop off second
		}
		fn(_0, _1)
	}
}
