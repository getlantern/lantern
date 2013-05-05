package otto

import (
	"strconv"
	"strings"
)

// Array

func builtinArray(call FunctionCall) Value {
	return toValue(builtinNewArrayNative(call.runtime, call.ArgumentList))
}

func builtinNewArray(self *_object, _ Value, argumentList []Value) Value {
	return toValue(builtinNewArrayNative(self.runtime, argumentList))
}

func builtinNewArrayNative(runtime *_runtime, argumentList []Value) *_object {
	if len(argumentList) == 1 {
		return runtime.newArray(toUint32(argumentList[0]))
	}
	return runtime.newArrayOf(argumentList)
}

func builtinArray_concat(call FunctionCall) Value {
	//return toValue(call.runtime.newArray(0))
	thisObject := call.thisObject()
	valueArray := []Value{}
	source := append([]Value{toValue(thisObject)}, call.ArgumentList...)
	for _, item := range source {
		switch item._valueType {
		case valueObject:
			object := item._object()
			if isArray(object) {
				lengthValue := object.get("length")
				// FIXME This was causing a panic?
				//length := lengthValue.value.(uint32)
				length := toUint32(lengthValue)
				for index := uint32(0); index < length; index += 1 {
					name := strconv.FormatInt(int64(index), 10)
					if !object.hasProperty(name) {
						continue
					}
					value := object.get(name)
					valueArray = append(valueArray, value)
				}
				continue
			}
			fallthrough
		default:
			valueArray = append(valueArray, toValue(toString(item)))
		}
	}
	return toValue(call.runtime.newArrayOf(valueArray))
}

func builtinArray_shift(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUint32(thisObject.get("length")))
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
	thisObject.delete(arrayIndexToString(length-1), true)
	thisObject.put("length", toValue(length-1), true)
	return first
}

func builtinArray_push(call FunctionCall) Value {
	thisObject := call.thisObject()
	itemList := call.ArgumentList
	index := uint(toUint32(thisObject.get("length")))
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
	length := uint(toUint32(thisObject.get("length")))
	if 0 == length {
		thisObject.put("length", toValue(length), true)
		return UndefinedValue()
	}
	last := thisObject.get(arrayIndexToString(length - 1))
	thisObject.delete(arrayIndexToString(length-1), true)
	thisObject.put("length", toValue(length-1), true)
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
	length := uint(toUint32(thisObject.get("length")))
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
	return toValue(strings.Join(stringList, separator))
}

func builtinArray_splice(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUint32(thisObject.get("length")))

	start := valueToRangeIndex(call.Argument(0), length, false)
	deleteCount := valueToRangeIndex(call.Argument(1), uint(int64(length)-start), true)
	valueArray := make([]Value, deleteCount)

	for index := int64(0); index < deleteCount; index++ {
		indexString := arrayIndexToString(uint(start + index))
		if thisObject.hasProperty(indexString) {
			valueArray[index] = thisObject.get(indexString)
		}
	}

	// 0, <1, 2, 3, 4>, 5, 6, 7
	// a, b
	// length 8 - delete 4 @ start 1

	itemList := []Value{}
	itemCount := int64(len(call.ArgumentList))
	if itemCount > 2 {
		itemCount -= 2 // Less the first two arguments
		itemList = call.ArgumentList[2:]
	} else {
		itemCount = 0
	}
	if itemCount < deleteCount {
		// The Object/Array is shrinking
		stop := int64(length) - deleteCount
		// The new length of the Object/Array before
		// appending the itemList remainder
		// Stopping at the lower bound of the insertion:
		// Move an item from the after the deleted portion
		// to a position after the inserted portion
		for index := start; index < stop; index++ {
			from := arrayIndexToString(uint(index + deleteCount)) // Position just after deletion
			to := arrayIndexToString(uint(index + itemCount))     // Position just after splice (insertion)
			if thisObject.hasProperty(from) {
				thisObject.put(to, thisObject.get(from), true)
			} else {
				thisObject.delete(to, true)
			}
		}
		// Delete off the end
		// We don't bother to delete below <stop + itemCount> (if any) since those
		// will be overwritten anyway
		for index := int64(length); index > (stop + itemCount); index-- {
			thisObject.delete(arrayIndexToString(uint(index-1)), true)
		}
	} else if itemCount > deleteCount {
		// The Object/Array is growing
		// The itemCount is greater than the deleteCount, so we do
		// not have to worry about overwriting what we should be moving
		// ---
		// Starting from the upper bound of the deletion:
		// Move an item from the after the deleted portion
		// to a position after the inserted portion
		for index := int64(length) - deleteCount; index > start; index-- {
			from := arrayIndexToString(uint(index + deleteCount - 1))
			to := arrayIndexToString(uint(index + itemCount - 1))
			if thisObject.hasProperty(from) {
				thisObject.put(to, thisObject.get(from), true)
			} else {
				thisObject.delete(to, true)
			}
		}
	}

	for index := int64(0); index < itemCount; index++ {
		thisObject.put(arrayIndexToString(uint(index+start)), itemList[index], true)
	}
	thisObject.put("length", toValue(uint(int64(length)+itemCount-deleteCount)), true)

	return toValue(call.runtime.newArrayOf(valueArray))
}

func builtinArray_slice(call FunctionCall) Value {
	thisObject := call.thisObject()

	length := uint(toUint32(thisObject.get("length")))
	start, end := rangeStartEnd(call.ArgumentList, length, false)

	if start >= end {
		// Always an empty array
		return toValue(call.runtime.newArray(0))
	}
	sliceLength := end - start
	sliceValueArray := make([]Value, sliceLength)

	for index := int64(0); index < sliceLength; index++ {
		from := arrayIndexToString(uint(index + start))
		if thisObject.hasProperty(from) {
			sliceValueArray[index] = thisObject.get(from)
		}
	}

	return toValue(call.runtime.newArrayOf(sliceValueArray))
}

func builtinArray_unshift(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUint32(thisObject.get("length")))
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
	length := uint(toUint32(thisObject.get("length")))

	lower := struct {
		name   string
		index  uint
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
		name    string
		exists  bool
		defined bool
		value   string
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

	return int(toInt32(compare.Call(UndefinedValue(), []Value{x, y})))
}

func arraySortSwap(thisObject *_object, index0, index1 uint) {

	j := struct {
		name   string
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
		pivot := left + (right-left)/2
		pivot = arraySortQuickPartition(thisObject, left, right, pivot, compare)
		if pivot > 0 {
			arraySortQuickSort(thisObject, left, pivot-1, compare)
		}
		arraySortQuickSort(thisObject, pivot+1, right, compare)
	}
}

func builtinArray_sort(call FunctionCall) Value {
	thisObject := call.thisObject()
	length := uint(toUint32(thisObject.get("length")))
	compareValue := call.Argument(0)
	compare := compareValue._object()
	if compareValue.IsUndefined() {
	} else if !compareValue.isCallable() {
		panic(newTypeError())
	}
	if length > 1 {
		arraySortQuickSort(thisObject, 0, length-1, compare)
	}
	return call.This
}

func builtinArray_isArray(call FunctionCall) Value {
	return toValue(isArray(call.Argument(0)._object()))
}
