package otto

import (
	"strconv"
	"math"
	"fmt"
	"strings"
	runtime_ "runtime"
	"regexp"
)

var isIdentifier_Regexp *regexp.Regexp = regexp.MustCompile(`^[a-zA-Z\$][a-zA-Z0-9\$]*$`)

func isIdentifier(string_ string ) bool {
	return isIdentifier_Regexp.MatchString(string_)
}

func toValueArray(arguments... interface{}) []Value {
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

func valueToArrayIndex(indexValue Value, length uint, negativeIndex bool) uint {
	index := toIntegerFloat(indexValue)
	if negativeIndex {
		if 0 > length {
			return uint(index)
		}
		if 0 > index {
			index = math.Max(index + float64(length), 0)
		} else {
			index = math.Min(index, float64(length))
		}
		return uint(index)
	}
	{
		index := uint(math.Max(index, 0))
		if 0 > length {
			return index
		}
		// minimum(index, length)
		if index > length {
			return length
		}
		return index
	}
}

func dbg(arguments... interface{}) {
	output := []string{}
	for _, argument := range arguments {
		output = append(output, fmt.Sprintf("%v", argument))
	}
	fmt.Println(strings.Join(output, " "))
}

func boolFields(input string) (result map[string]bool) {
	result = map[string]bool{}
	for _, word := range strings.Fields(input) {
		result[word] = true
	}
	return result
}

func hereBeDragons(arguments... interface{}) string {
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

func throwHereBeDragons(arguments... interface{}) {
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

