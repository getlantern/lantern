package otto

import (
	"bytes"
	"math"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf16"
)

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
		chrList[index] = toUint16(value)
	}
	return toValue(chrList)
}

func builtinString_charAt(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	value16 := utf16.Encode([]rune(value))
	index := toInteger(call.Argument(0))
	if 0 > index || index >= int64(len(value16)) {
		return toValue("")
	}
	return toValue(string(value16[index]))
}

func builtinString_charCodeAt(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	value := toString(call.This)
	value16 := utf16.Encode([]rune(value))
	index := toInteger(call.Argument(0))
	if 0 > index || index >= int64(len(value16)) {
		return NaNValue()
	}
	return toValue(value16[index])
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
	start := float64(_toInteger(call.Argument(1)))
	if 0 > start {
		start = 0
	} else if start >= float64(len(value)) {
		if target == "" {
			return toValue(len(value))
		}
		return toValue(-1)
	}
	return toValue(strings.Index(value[int(start):], target))
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
	replacement := builtinString_replace_Regexp.ReplaceAllFunc(replaceValue, func(part []byte) []byte {
		// TODO Check if match[0] or match[1] can be -1 in this scenario
		switch part[1] {
		case '$':
			return []byte{'$'}
		case '&':
			return target[match[0]:match[1]]
		case '`':
			return target[:match[0]]
		case '\'':
			return target[match[1] : len(target)-1]
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
				argumentList := make([]Value, matchCount+2)
				for index := 0; index < matchCount; index++ {
					offset := 2 * index
					if match[offset] != -1 {
						argumentList[index] = toValue(target[match[offset]:match[offset+1]])
					} else {
						argumentList[index] = UndefinedValue()
					}
				}
				argumentList[matchCount+0] = toValue(match[0])
				argumentList[matchCount+1] = toValue(target)
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
	if int64(index)+searchLength > searchLength {
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
		limit = int(toUint32(limitValue))
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
	if end-start <= 0 {
		return toValue("")
	}
	return toValue(target[start:end])
}

func builtinString_substring(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	target := toString(call.This)

	length := uint(len(target))
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

	if start+length >= size {
		// Cap length to be to the end of the string
		// start = 3, length = 5, size = 4 [0, 1, 2, 3]
		// 4 - 3 = 1
		// target[3:4]
		length = size - start
	}

	return toValue(target[start : start+length])
}

func builtinString_toLowerCase(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	return toValue(strings.ToLower(toString(call.This)))
}

func builtinString_toUpperCase(call FunctionCall) Value {
	checkObjectCoercible(call.This)
	return toValue(strings.ToUpper(toString(call.This)))
}
