package otto

import (
	"strings"
	"fmt"
	"strconv"
	"math"
	"bytes"
	"regexp"
	"math/rand"
	time_ "time"
	"net/url"
	"unicode/utf16"
)

// Global
func builtinGlobal_eval(call FunctionCall) Value {
	source := call.Argument(0)
	if !source.IsString() {
		return source
	}
	program, err := parse(toString(source))
	if err != nil {
		//panic(call.runtime.newError("SyntaxError", UndefinedValue()))
		panic(&_syntaxError{Message: fmt.Sprintf("%v", err)})
	}
	runtime := call.runtime
	runtime.EnterEvalExecutionContext(call)
	defer runtime.LeaveExecutionContext()
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
		radixValue = int(toInteger(radix))
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

// Object

func builtinObject(call FunctionCall) Value {
	value := call.Argument(0)
	switch value._valueType {
	case valueUndefined, valueNull:
		return toValue(call.runtime.newObject())
	}

	return toValue(call.runtime.toObject(value))
}

func builtinNewObject(self *_object, _ Value, _ []Value) Value {
	return toValue(self.runtime.newObject())
}

func builtinObject_toString(call FunctionCall) Value {
	result := ""
	if call.This.IsUndefined() {
		result = "[object Undefined]"
	} else if call.This.IsNull() {
		result = "[object Null]"
	} else {
		result = fmt.Sprintf("[object %s]", call.thisObject().class)
	}
	return toValue(result)
}

func builtinObject_getOwnPropertyDescriptor(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}

	name := toString(call.Argument(1))
	descriptor := object.getOwnProperty(name)
	if descriptor == nil {
		return UndefinedValue()
	}
	return toValue(call.runtime.fromPropertyDescriptor(*descriptor))
}

func builtinObject_defineProperty(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}
	name := toString(call.Argument(1))
	descriptor := toPropertyDescriptor(call.Argument(2))
	object.defineOwnProperty(name, descriptor, true)
	return objectValue
}

func builtinObject_defineProperties(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}

	properties := call.runtime.toObject(call.Argument(1))
	properties.enumerate(func(name string) {
		descriptor := toPropertyDescriptor(properties.get(name))
		object.defineOwnProperty(name, descriptor, true)
	})

	return objectValue
}

func builtinObject_create(call FunctionCall) Value {
	prototypeValue := call.Argument(0)
	prototype := prototypeValue._object()
	if prototype == nil {
		panic(newTypeError())
	}

	object := call.runtime.newObject()

	propertiesValue := call.Argument(1)
	if propertiesValue.IsDefined() {
		properties := call.runtime.toObject(propertiesValue)
		properties.enumerate(func(name string) {
			descriptor := toPropertyDescriptor(properties.get(name))
			object.defineOwnProperty(name, descriptor, true)
		})
	}

	return toValue(object)
}

// Function

func builtinFunction(call FunctionCall) Value {
	return toValue(builtinNewFunctionNative(call.runtime, call.ArgumentList))
}

func builtinNewFunction(self *_object, _ Value, argumentList []Value) Value {
	return toValue(builtinNewFunctionNative(self.runtime, argumentList))
}

func builtinNewFunctionNative(runtime *_runtime, argumentList []Value) *_object {
	parameterList := []string{}
	bodySource := ""
	argumentCount := len(argumentList)
	if argumentCount > 0 {
		bodySource = toString(argumentList[argumentCount-1])
		argumentList = argumentList[0:argumentCount-1]
		for _, value := range argumentList {
			parameterList = append(parameterList, toString(value))
		}
	}

	parser := newParser()
	parser.lexer.Source = bodySource
	_programNode := parser.ParseAsFunction()
	return runtime.newNodeFunction(_programNode.toFunction(parameterList), runtime.GlobalEnvironment)
}

func builtinFunction_apply(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue(call.runtime.GlobalObject)
	}
	argumentList := call.Argument(1)
	switch argumentList._valueType {
	case valueUndefined, valueNull:
		return call.thisObject().Call(this, []Value{})
	case valueObject:
	default:
		panic(newTypeError())
	}

	arrayObject := argumentList._object()
	thisObject := call.thisObject()
	length := uint(toUI32(arrayObject.get("length")))
	valueArray := make([]Value, length)
	for index := uint(0); index < length; index++ {
		valueArray[index] = arrayObject.get(arrayIndexToString(index))
	}
	return thisObject.Call(this, valueArray)
}

func builtinFunction_call(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	thisObject := call.thisObject()
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue(call.runtime.GlobalObject)
	}
	if len(call.ArgumentList) >= 1 {
		return thisObject.Call(this, call.ArgumentList[1:])
	}
	return thisObject.Call(this, []Value{})
}

// Boolean

func builtinBoolean(call FunctionCall) Value {
	return toValue(toBoolean(call.Argument(0)))
}

func builtinNewBoolean(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newBoolean(valueOfArrayIndex(argumentList, 0)))
}

// String

func stringValueFromStringArgumentList(argumentList []Value) Value {
    if len(argumentList) > 0 {
	    return toValue(toString(argumentList[0]))
    }
    return toValue("")
}

func builtinString(call FunctionCall) Value {
    return stringValueFromStringArgumentList(call.ArgumentList)
}

func builtinNewString(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newString(stringValueFromStringArgumentList(argumentList)))
}

func builtinString_fromCharCode(call FunctionCall) Value {
	chrList := make([]uint16, len(call.ArgumentList))
	for index, value := range call.ArgumentList {
		chrList[index] = toUI16(value)
	}
	return toValue(string(utf16.Decode(chrList)))
}

func builtinString_charAt(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	index := toInteger(call.Argument(0))
	if 0 > index || index >= int64(len(value)) {
		return toValue("")
	}
	return toValue(string(value[index]))
}

func builtinString_charCodeAt(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	index := toInteger(call.Argument(0))
	if 0 > index || index >= int64(len(value)) {
		return NaNValue()
	}
	return toValue(value[index])
}

func builtinString_concat(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	var value bytes.Buffer
	value.WriteString(toString(call.This))
	for _, item := range call.ArgumentList {
		value.WriteString(toString(item))
	}
	return toValue(value.String())
}

func builtinString_indexOf(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	target := toString(call.Argument(0))
	if 2 > len(call.ArgumentList) {
		return toValue(strings.Index(value, target))
	}
	start := toInteger(call.Argument(1))
	if 0 > start {
		start = 0
	} else if start >= int64(len(value)) {
		if target == "" {
			return toValue(len(value))
		}
		return toValue(-1)
	}
	return toValue(strings.Index(value[start:], target))
}

func builtinString_lastIndexOf(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	target := toString(call.Argument(0))
	if 2 > len(call.ArgumentList) || call.ArgumentList[1].IsUndefined() {
		return toValue(strings.LastIndex(value, target))
	}
	length := len(value)
	if length == 0 {
		return toValue(strings.LastIndex(value, target))
	}
	startNumber := toFloat(call.ArgumentList[1])
	start := int64(0)
	if math.IsNaN(startNumber) || math.IsInf(startNumber, 0) {
		// startNumber is infinity, so start is the end of string (start = length)
		return toValue(strings.LastIndex(value, target))
	} else {
		start = toInteger(call.ArgumentList[1])
	}
	if 0 > start {
		start = 0
	} else if start >= int64(length) {
		return toValue(strings.LastIndex(value, target))
	}
	return toValue(strings.LastIndex(value[:start], target))
}

func builtinString_match(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)
	matcherValue := call.Argument(0)
	matcher := matcherValue._object()
	if !matcherValue.IsObject() || matcher.class != "RegExp" {
		matcher = call.runtime.newRegExp(matcherValue, UndefinedValue())
	}
	global := toBoolean(matcher.get("global"))
	if !global {
		match, result := execRegExp(matcher, target)
		if !match {
			return NullValue()
		}
		return toValue(execResultToArray(call.runtime, target, result))
	}

	{
		result := matcher._RegExp.RegularExpression.FindAllStringIndex(target, -1)
		matchCount := len(result)
		if result == nil {
			matcher.set("lastIndex", toValue(0), true)
			return UndefinedValue() // !match
		}
		matchCount = len(result)
		valueArray := make([]Value, matchCount)
		for index := 0; index < matchCount; index++ {
			valueArray[index] = toValue(target[result[index][0]:result[index][1]])
		}
		matcher.set("lastIndex", toValue(result[matchCount-1][1]), true)
		return toValue(call.runtime.newArray(valueArray))
	}
}

var builtinString_replace_Regexp = regexp.MustCompile("\\$(?:[\\$\\&\\'\\`1-9]|0[1-9]|[1-9][0-9])")

func builtinString_findAndReplaceString(input []byte, lastIndex int, match []int, target []byte, replaceValue []byte) (output []byte) {
	matchCount := len(match) / 2
	output = input
	if match[0] != lastIndex {
		output = append(output, target[lastIndex:match[0]]...)
	}
	replacement := builtinString_replace_Regexp.ReplaceAllFunc(replaceValue, func(part []byte) []byte{
		// TODO Check if match[0] or match[1] can be -1 in this scenario
		switch part[1] {
		case '$':
			return []byte{'$'}
		case '&':
			return target[match[0]:match[1]]
		case '`':
			return target[:match[0]]
		case '\'':
			return target[match[1]:len(target)-1]
		}
		matchNumberParse, error := strconv.ParseInt(string(part[1:]), 10, 64)
		matchNumber := int(matchNumberParse)
		if error != nil || matchNumber >= matchCount {
			return []byte{}
		}
		offset := 2 * matchNumber
		if match[offset] != -1 {
			return target[match[offset]:match[offset+1]]
		}
		return []byte{} // The empty string
	})
	output = append(output, replacement...)
	return output
}

func builtinString_replace(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := []byte(toString(call.This))
	searchValue := call.Argument(0)
	searchObject := searchValue._object()

	// TODO If a capture is -1?
	var search *regexp.Regexp
	global := false
	find := 1
	if searchValue.IsObject() && searchObject.class == "RegExp" {
		search = searchObject._RegExp.RegularExpression
		global = toBoolean(searchObject.get("global"))
		if global {
			find = -1
		}
	} else {
		search = regexp.MustCompile(regexp.QuoteMeta(toString(searchValue)))
	}

	found := search.FindAllSubmatchIndex(target, find)
	if found == nil {
		return toValue(string(target)) // !match
	}

	{
		lastIndex := 0
		result := []byte{}

		replaceValue := call.Argument(1)
		if replaceValue.isCallable() {
			target := string(target)
			replace := replaceValue._object()
			for _, match := range found {
				if match[0] != lastIndex {
					result = append(result, target[lastIndex:match[0]]...)
				}
				matchCount := len(match) / 2
				argumentList := make([]Value, matchCount + 2)
				for index := 0; index < matchCount; index++ {
					offset := 2 * index
					if match[offset] != -1 {
						argumentList[index] = toValue(target[match[offset]:match[offset+1]])
					} else {
						argumentList[index] = UndefinedValue()
					}
				}
				argumentList[matchCount + 0] = toValue(match[0])
				argumentList[matchCount + 1] = toValue(target)
				replacement := toString(replace.Call(UndefinedValue(), argumentList))
				result = append(result, []byte(replacement)...)
				lastIndex = match[1]
			}

		} else {
			replace := []byte(toString(replaceValue))
			for _, match := range found {
				result = builtinString_findAndReplaceString(result, lastIndex, match, target, replace)
				lastIndex = match[1]
			}
		}

		if lastIndex != len(target) {
			result = append(result, target[lastIndex:]...)
		}

		if global && searchObject != nil {
			searchObject.put("lastIndex", toValue(lastIndex), true)
		}

		return toValue(string(result))
	}

	return UndefinedValue()
}

func builtinString_search(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)
	searchValue := call.Argument(0)
	search := searchValue._object()
	if !searchValue.IsObject() || search.class != "RegExp" {
		search = call.runtime.newRegExp(searchValue, UndefinedValue())
	}
	result := search._RegExp.RegularExpression.FindStringIndex(target)
	if result == nil {
		return toValue(-1)
	}
	return toValue(result[0])
}

func stringSplitMatch(target string, targetLength int64, index uint, search string, searchLength int64) (bool, uint) {
	if int64(index) + searchLength > searchLength {
		return false, 0
	}
	found := strings.Index(target[index:], search)
	if 0 > found {
		return false, 0
	}
	return true, uint(found)
}

func builtinString_split(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)

	separatorValue := call.Argument(0)
	limitValue := call.Argument(1)
	limit := -1
	if limitValue.IsDefined() {
		limit = int(toUI32(limitValue))
	}

	if limit == 0 {
		return toValue(call.runtime.newArray([]Value{}))
	}

	if separatorValue.IsUndefined() {
		return toValue(call.runtime.newArray([]Value{toValue(target)}))
	}

	if separatorValue.isRegExp() {
		targetLength := len(target)
		search := separatorValue._object()._RegExp.RegularExpression
		valueArray := []Value{}
		result := search.FindAllStringSubmatchIndex(target, -1)
		lastIndex := 0
		found := 0

		for _, match := range result {
			if match[0] == match[1] {
				// An "empty" match
				continue
			}

			if lastIndex != match[0] {
				valueArray = append(valueArray, toValue(target[lastIndex:match[0]]))
				found++
			} else if lastIndex == match[0] {
				if lastIndex != -1 {
					valueArray = append(valueArray, toValue(""))
					found++
				}
			}

			lastIndex = match[1]
			if found == limit {
				goto RETURN
			}

			captureCount := len(match) / 2
			for index := 1; index < captureCount; index++ {
				offset := index * 2
				value := UndefinedValue()
				if match[offset] != -1 {
					value = toValue(target[match[offset]:match[offset+1]])
				}
				valueArray = append(valueArray, value)
				found++
				if found == limit {
					goto RETURN
				}
			}
		}

		if found != limit {
			if lastIndex != targetLength {
				valueArray = append(valueArray, toValue(target[lastIndex:targetLength]))
			} else {
				valueArray = append(valueArray, toValue(""))
			}
		}

RETURN:
		return toValue(call.runtime.newArray(valueArray))

	} else {
		separator := toString(separatorValue)

		splitLimit := limit
		excess := false
		if limit > 0 {
			splitLimit = limit + 1
			excess = true
		}

		split := strings.SplitN(target, separator, splitLimit)

		if excess && len(split) > limit {
			split = split[:limit]
		}

		valueArray := make([]Value, len(split))
		for index, value := range split {
			valueArray[index] = toValue(value)
		}

		return toValue(call.runtime.newArray(valueArray))
	}

	return UndefinedValue()
}

func builtinString_slice(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)

	length := uint(len(target))
	start, end := rangeStartEnd(call.ArgumentList, length, false)
	if 0 >= end - start {
		return toValue("")
	}
	return toValue(target[start:end])
}

func builtinString_substring(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)

	length := uint(len(target))
	//start := valueToArrayIndex(call.Argument(0), size, false)
	//end := valueToArrayIndex(call.Argument(1), size, false)
	start, end := rangeStartEnd(call.ArgumentList, length, true)
	if start > end {
		start, end = end, start
	}
	return toValue(target[start:end])
}

func builtinString_substr(call FunctionCall) Value {
	target := toString(call.This)

	size := int64(len(target))
	start, length := rangeStartLength(call.ArgumentList, uint(size))

	if start >= size {
		return toValue("")
	}

	if length <= 0 {
		return toValue("")
	}

	if start + length >= size {
		// Cap length to be to the end of the string
		// start = 3, length = 5, size = 4 [0, 1, 2, 3]
		// 4 - 3 = 1 
		// target[3:4]
		length = size - start
	}

	return toValue(target[start:start+length])
}

func builtinString_toLowerCase(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	return toValue(strings.ToLower(toString(call.This)))
}

func builtinString_toUpperCase(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	return toValue(strings.ToUpper(toString(call.This)))
}

// Number

func numberValueFromNumberArgumentList(argumentList []Value) Value {
    if len(argumentList) > 0 {
	    return toValue(toNumber(argumentList[0]))
    }
    return toValue(0)
}

func builtinNumber(call FunctionCall) Value {
    return numberValueFromNumberArgumentList(call.ArgumentList)
}

func builtinNewNumber(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newNumber(numberValueFromNumberArgumentList(argumentList)))
}

// Array

func builtinArray(call FunctionCall) Value {
	return toValue(builtinNewArrayNative(call.runtime, call.ArgumentList))
}

func builtinNewArray(self *_object, _ Value, argumentList []Value) Value {
	return toValue(builtinNewArrayNative(self.runtime, argumentList))
}

func builtinNewArrayNative(runtime *_runtime, argumentList []Value) *_object {
	valueArray := argumentList
	if len(argumentList) == 1 {
		value := argumentList[0]
		if value.IsNumber() {
			numberValue := uint(toUI32(value))
			if float64(numberValue) == toFloat(value) {
				valueArray = make([]Value, numberValue)
			} else {
				panic(newRangeError())
			}
		}
	}
	return runtime.newArray(valueArray)
}

func builtinArray_concat(call FunctionCall) Value {
	thisObject := call.thisObject()
	valueArray := []Value{}
	itemList := append([]Value{toValue(thisObject)}, call.ArgumentList...)
	for len(itemList) > 0 {
		item := itemList[0]
		itemList = itemList[1:]
		switch item._valueType {
		case valueObject:
			value := item._object()
			if value.class == "Array" {
				itemValueArray := value.stash.(*_arrayStash).valueArray
				for _, item := range itemValueArray {
					if item._valueType == valueEmpty {
						continue
					}
					valueArray = append(valueArray, item)
				}
				continue
			}
			fallthrough
		default:
			valueArray = append(valueArray, item)
		}
	}
	return toValue(call.runtime.newArray(valueArray))
}

func builtinArray_shift(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))
	if 0 == length {
		thisObject.put("length", toValue(length), true)
		return UndefinedValue()
	}
	first := thisObject.get("0")
	for index := uint(1); index < length; index++ {
		from := arrayIndexToString(index)
		to := arrayIndexToString(index - 1)
		if thisObject.hasProperty(from) {
			thisObject.put(to, thisObject.get(from), true)
		} else {
			thisObject.delete(to, true)
		}
	}
	thisObject.delete(arrayIndexToString(length - 1), true)
	thisObject.put("length", toValue(length - 1), true)
	return first
}

func builtinArray_push(call FunctionCall) Value {
	thisObject := call.thisObject()
	itemList := call.ArgumentList
	index := uint(toUI32(thisObject.get("length")))
	for len(itemList) > 0 {
		thisObject.put(arrayIndexToString(index), itemList[0], true)
		itemList = itemList[1:]
		index += 1
	}
	length := toValue(index)
	thisObject.put("length", length, true)
	return length
}

func builtinArray_pop(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))
	if 0 == length {
		thisObject.put("length", toValue(length), true)
		return UndefinedValue()
	}
	last := thisObject.get(arrayIndexToString(length - 1))
	thisObject.delete(arrayIndexToString(length - 1), true)
	thisObject.put("length", toValue(length - 1), true)
	return last
}

func builtinArray_join(call FunctionCall) Value {
	separator := ","
	{
		argument := call.Argument(0)
		if argument.IsDefined() {
			separator = toString(argument)
		}
	}
	thisObject := call.thisObject()
	if stash, isArray := thisObject.stash.(*_arrayStash); isArray {
		return toValue(builtinArray_joinNative(stash.valueArray, separator))
	}
	// Generic .join
	length := uint(toUI32(thisObject.get("length")))
	if length == 0 {
		return toValue("")
	}
	stringList := make([]string, 0, length)
	for index := uint(0); index < length; index += 1 {
		value := thisObject.get(arrayIndexToString(index))
		stringValue := ""
		switch value._valueType {
		case valueEmpty, valueUndefined, valueNull:
		default:
			stringValue = toString(value)
		}
		stringList = append(stringList, stringValue)
	}
	return toValue(strings.Join(stringList, ","))
}

func builtinArray_joinNative(valueArray []Value, separator string) string {
	length := len(valueArray)
	if length == 0 {
		return ""
	}
	stringList := make([]string, 0, length)
	for index := 0; index < length; index++ {
		value := valueArray[index]
		stringValue := ""
		switch value._valueType {
		case valueEmpty, valueUndefined, valueNull:
		default:
			stringValue = toString(value)
		}
		stringList = append(stringList, stringValue)
	}
	return strings.Join(stringList, separator)
}

func rangeStartEnd(source []Value, size uint, negativeIsZero bool) (start, end uint) {
	start = valueToArrayIndex(valueOfArrayIndex(source, 0), size, negativeIsZero)
	if len(source) == 1 {
		// If there is only the start argument, then end = size
		end = size
		return
	}

	// Assuming the argument is undefined...
	end = size
	endValue := valueOfArrayIndex(source, 1)
	if !endValue.IsUndefined() {
		// Which it is not, so get the value as an array index
		end = valueToArrayIndex(endValue, size, negativeIsZero)
	}
	return
}

func rangeStartLength(source []Value, size uint) (start, length int64) {
	start = int64(valueToArrayIndex(valueOfArrayIndex(source, 0), size, false))

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

func builtinArray_splice(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))

	start := valueToArrayIndex(call.Argument(0), length, false)
	deleteCount := valueToArrayIndex(call.Argument(1), length - start, true)
	valueArray := make([]Value, deleteCount)

	for index := uint(0); index < deleteCount; index++ {
		indexString := arrayIndexToString(start + index)
		if thisObject.hasProperty(indexString) {
			valueArray[index] = thisObject.get(indexString)
		}
	}

	// 0, <1, 2, 3, 4>, 5, 6, 7
	// a, b
	// length 8 - delete 4 @ start 1

	itemList := []Value{}
	itemCount := uint(len(call.ArgumentList))
	if itemCount > 2 {
		itemCount -= 2 // Less the first two arguments
		itemList = call.ArgumentList[2:]
	} else {
		itemCount = 0
	}
	if itemCount < deleteCount {
		// The Object/Array is shrinking
		stop := length - deleteCount // The new length of the Object/Array before
									 // appending the itemList remainder
		// Stopping at the lower bound of the insertion:
		// Move an item from the after the deleted portion
		// to a position after the inserted portion
		for index := start; index < stop; index++ {
			from := arrayIndexToString(index + deleteCount) // Position just after deletion
			to := arrayIndexToString(index + itemCount) // Position just after splice (insertion)
			if thisObject.hasProperty(from) {
				thisObject.put(to, thisObject.get(from), true)
			} else {
				thisObject.delete(to, true)
			}
		}
		// Delete off the end
		// We don't bother to delete below <stop + itemCount> (if any) since those
		// will be overwritten anyway
		for index := length; index > (stop + itemCount); index-- {
			thisObject.delete(arrayIndexToString(index - 1), true)
		}
	} else if itemCount > deleteCount {
		// The Object/Array is growing
		// The itemCount is greater than the deleteCount, so we do
		// not have to worry about overwriting what we should be moving
		// ---
		// Starting from the upper bound of the deletion:
		// Move an item from the after the deleted portion
		// to a position after the inserted portion
		for index := length - deleteCount; index > start; index-- {
			from := arrayIndexToString(index + deleteCount - 1)
			to := arrayIndexToString(index + itemCount - 1)
			if thisObject.hasProperty(from) {
				thisObject.put(to, thisObject.get(from), true)
			} else {
				thisObject.delete(to, true)
			}
		}
	}

	for index := uint(0); index < itemCount; index++ {
		thisObject.put(arrayIndexToString(index + start), itemList[index], true)
	}
	thisObject.put("length", toValue(length + itemCount - deleteCount), true)

	return toValue(call.runtime.newArray(valueArray))
}

func builtinArray_slice(call FunctionCall) Value {
	thisObject := call.thisObject()

	length := uint(toUI32(thisObject.get("length")))
	start, end := rangeStartEnd(call.ArgumentList, length, false)

	if start >= end {
		// Always an empty array
		return toValue(call.runtime.newArray([]Value{}))
	}
	sliceLength := end - start
	sliceValueArray := make([]Value, sliceLength)

	// Native slicing if a "real" array
	if _arrayStash, ok := thisObject.stash.(*_arrayStash); ok {
		copy(sliceValueArray, _arrayStash.valueArray[start:start+sliceLength])
	} else {
		for index := uint(0); index < sliceLength; index++ {
			from := arrayIndexToString(index + start)
			if thisObject.hasProperty(from) {
				sliceValueArray[index] = thisObject.get(from)
			}
		}
	}

	return toValue(call.runtime.newArray(sliceValueArray))
}

func builtinArray_unshift(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))
	itemList := call.ArgumentList
	itemCount := uint(len(itemList))

	for index := length; index > 0; index-- {
		from := arrayIndexToString(index - 1)
		to := arrayIndexToString(index + itemCount - 1)
		if thisObject.hasProperty(from) {
			thisObject.put(to, thisObject.get(from), true)
		} else {
			thisObject.delete(to, true)
		}
	}

	for index := uint(0); index < itemCount; index++ {
		thisObject.put(arrayIndexToString(index), itemList[index], true)
	}

	newLength := toValue(length + itemCount)
	thisObject.put("length", newLength, true)
	return newLength
}

func builtinArray_reverse(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))

	lower := struct {
		name string
		index uint
		exists bool
	}{}
	upper := lower

	lower.index = 0
	middle := length / 2 // Division will floor

	for lower.index != middle {
		lower.name = arrayIndexToString(lower.index)
		upper.index = length - lower.index - 1
		upper.name = arrayIndexToString(upper.index)

		lower.exists = thisObject.hasProperty(lower.name)
		upper.exists = thisObject.hasProperty(upper.name)

		if lower.exists && upper.exists {
			lowerValue := thisObject.get(lower.name)
			upperValue := thisObject.get(upper.name)
			thisObject.put(lower.name, upperValue, true)
			thisObject.put(upper.name, lowerValue, true)
		} else if !lower.exists && upper.exists {
			value := thisObject.get(upper.name)
			thisObject.delete(upper.name, true)
			thisObject.put(lower.name, value, true)
		} else if lower.exists && !upper.exists {
			value := thisObject.get(lower.name)
			thisObject.delete(lower.name, true)
			thisObject.put(upper.name, value, true)
		} else {
			// Nothing happens.
		}

		lower.index += 1
	}

	return call.This
}

func sortCompare(thisObject *_object, index0, index1 uint, compare *_object) int {
	j := struct {
		name string
		exists bool
		defined bool
		value string
	}{}
	k := j
	j.name = arrayIndexToString(index0)
	j.exists = thisObject.hasProperty(j.name)
	k.name = arrayIndexToString(index1)
	k.exists = thisObject.hasProperty(k.name)

	if !j.exists && !k.exists {
		return 0
	} else if !j.exists {
		return 1
	} else if !k.exists {
		return -1
	}

	x := thisObject.get(j.name)
	y := thisObject.get(k.name)
	j.defined = x.IsDefined()
	k.defined = y.IsDefined()

	if !j.defined && !k.defined {
		return 0
	} else if !j.defined {
		return 1
	} else if !k.defined {
		return -1
	}

	if compare == nil {
		j.value = toString(x)
		k.value = toString(y)

		if j.value == k.value {
			return 0
		} else if j.value < k.value {
			return -1
		}

		return 1
	}

	return int(toI32(compare.Call(UndefinedValue(), []Value{x, y})))
}

func arraySortSwap(thisObject *_object, index0, index1 uint) {

	j := struct {
		name string
		exists bool
	}{}
	k := j

	j.name = arrayIndexToString(index0)
	j.exists = thisObject.hasProperty(j.name)
	k.name = arrayIndexToString(index1)
	k.exists = thisObject.hasProperty(k.name)

	if j.exists && k.exists {
		jValue := thisObject.get(j.name)
		kValue := thisObject.get(k.name)
		thisObject.put(j.name, kValue, true)
		thisObject.put(k.name, jValue, true)
	} else if !j.exists && k.exists {
		value := thisObject.get(k.name)
		thisObject.delete(k.name, true)
		thisObject.put(j.name, value, true)
	} else if j.exists && !k.exists {
		value := thisObject.get(j.name)
		thisObject.delete(j.name, true)
		thisObject.put(k.name, value, true)
	} else {
		// Nothing happens.
	}
}

func arraySortQuickPartition(thisObject *_object, left, right, pivot uint, compare *_object) uint {
	arraySortSwap(thisObject, pivot, right) // Right is now the pivot value
	cursor := left
	for index := left; index < right; index++ {
		if sortCompare(thisObject, index, right, compare) == -1 { // Compare to the pivot value
			arraySortSwap(thisObject, index, cursor)
			cursor += 1
		}
	}
	arraySortSwap(thisObject, cursor, right)
	return cursor
}

func arraySortQuickSort(thisObject *_object, left, right uint, compare *_object) {
	if left < right {
		pivot := left + (right - left)/2
		pivot = arraySortQuickPartition(thisObject, left, right, pivot, compare)
		if pivot > 0 {
			arraySortQuickSort(thisObject, left, pivot - 1, compare)
		}
		arraySortQuickSort(thisObject, pivot + 1, right, compare)
	}
}

func builtinArray_sort(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUI32(thisObject.get("length")))
	compareValue := call.Argument(0)
	compare := compareValue._object()
	if compareValue.IsUndefined() {
	} else if !compareValue.isCallable() {
		panic(newTypeError())
	}
	if length > 1 {
		arraySortQuickSort(thisObject, 0, length - 1, compare)
	}
	return call.This
}

// RegExp

func builtinRegExp(call FunctionCall) Value {
	return toValue(call.runtime.newRegExp(call.Argument(0), call.Argument(1)))
}

func builtinNewRegExp(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newRegExp(valueOfArrayIndex(argumentList, 0), valueOfArrayIndex(argumentList, 1)))
}

func builtinRegExp_toString(call FunctionCall) Value {
	thisObject := call.thisObject()
	source := toString(thisObject.get("source"))
	flags := []byte{}
	if toBoolean(thisObject.get("global")) {
		flags = append(flags, 'g')
	}
	if toBoolean(thisObject.get("ignoreCase")) {
		flags = append(flags, 'i')
	}
	if toBoolean(thisObject.get("multiline")) {
		flags = append(flags, 'm')
	}
	return toValue(fmt.Sprintf("/%s/%s", source, flags))
}

func builtinRegExp_exec(call FunctionCall) Value {
	thisObject := call.thisObject()
	target := toString(call.Argument(0))
	match, result := execRegExp(thisObject, target)
	if !match {
		return NullValue()
	}
	return toValue(execResultToArray(call.runtime, target, result))
}

func builtinRegExp_test(call FunctionCall) Value {
	thisObject := call.thisObject()
	target := toString(call.Argument(0))
	match, _ := execRegExp(thisObject, target)
	return toValue(match)
}

// Math

func builtinMath_max(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return negativeInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	default:
		result := toFloat(call.ArgumentList[0])
		if math.IsNaN(result) {
			return NaNValue()
		}
		for _, value := range call.ArgumentList[1:] {
			value := toFloat(value)
			if math.IsNaN(value) {
				return NaNValue()
			}
			result = math.Max(result, value)
		}
		return toValue(result)
	}
	return UndefinedValue()
}

func builtinMath_min(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return positiveInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	default:
		result := toFloat(call.ArgumentList[0])
		if math.IsNaN(result) {
			return NaNValue()
		}
		for _, value := range call.ArgumentList[1:] {
			value := toFloat(value)
			if math.IsNaN(value) {
				return NaNValue()
			}
			result = math.Min(result, value)
		}
		return toValue(result)
	}
	return UndefinedValue()
}

func builtinMath_ceil(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	if math.IsNaN(number) {
		return NaNValue()
	}
	return toValue(math.Ceil(number))
}

func builtinMath_floor(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	if math.IsNaN(number) {
		return NaNValue()
	}
	return toValue(math.Floor(number))
}

func builtinMath_random(call FunctionCall) Value {
	return toValue(rand.Float64())
}

func builtinMath_pow(call FunctionCall) Value {
	// TODO Make sure this works according to the specification (15.8.2.13)
	return toValue(math.Pow(toFloat(call.Argument(0)), toFloat(call.Argument(1))))
}

// Date

func builtinDate(call FunctionCall) Value {
	return toValue(call.runtime.newDate(newDateTime(call.ArgumentList)))
}

func builtinNewDate(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newDate(newDateTime(argumentList)))
}

func builtinDate_toString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format(time_.RFC1123))
}

func builtinDate_toUTCString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Format(time_.RFC1123))
}

func builtinDate_getTime(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	// We do this (convert away from a float) so the user
	// does not get something back in exponential notation
	return toValue(int64(date.Epoch()))
}

func builtinDate_setTime(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	date.Set(toFloat(call.Argument(0)))
	return date.Value()
}

func _builtinDate_set(call FunctionCall, argumentCap int, dateLocal bool) (*_dateObject, *_ecmaTime) {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return nil, nil
	}
	for index := 0; index < len(call.ArgumentList) && index < argumentCap; index++ {
		value := call.Argument(index)
		if value.IsNaN() {
			date.SetNaN()
			return date, nil
		}
	}
	baseTime := date.Time()
	if dateLocal {
		baseTime = baseTime.Local()
	}
	ecmaTime := ecmaTime(baseTime)
	return date, &ecmaTime
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
