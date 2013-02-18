package otto

import (
	"strconv"
)

func (runtime *_runtime) newArrayObject(valueArray []Value) *_object {
	self := runtime.newObject()
	self.class = "Array"
	self.stash = newArrayStash(valueArray, self.stash)
	return self
}

// _arrayStash

type _arrayStash struct {
	valueArray []Value
	_stash
}

func newArrayStash(valueArray []Value, stash _stash) *_arrayStash {
	self := &_arrayStash{
		valueArray,
		stash,
	}
	return self
}

// read

func (self *_arrayStash) test(name string) bool {
	// length
	if name == "length" {
		return true
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		return index < int64(len(self.valueArray)) && self.valueArray[index]._valueType != valueEmpty
	}

	return self._stash.test(name)
}

func (self *_arrayStash) get(name string) Value {
	// length
	if name == "length" {
		return toValue(len(self.valueArray))
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		if index < int64(len(self.valueArray)) {
			value := self.valueArray[index]
			if value._valueType != valueEmpty {
				return value
			}
		}
		return UndefinedValue()
	}

	return self._stash.get(name)
}

func (self *_arrayStash) property(name string) *_property {
	// length
	if name == "length" {
		return &_property{
			value: toValue(len(self.valueArray)),
			mode:  0100, // +w-ec
		}
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		value := UndefinedValue()
		if index < int64(len(self.valueArray)) {
			value = self.valueArray[index]
		}
		return &_property{
			value: value,
			mode:  0111, // +wec
		}
	}

	return self._stash.property(name)
}

func (self *_arrayStash) enumerate(each func(string)) {
	// .0, .1, .2, ...
	for index, _ := range self.valueArray {
		if self.valueArray[index]._valueType == valueEmpty {
			continue // A sparse array
		}
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}
	self._stash.enumerate(each)
}

// write

func (self *_arrayStash) canPut(name string) bool {
	// length
	if name == "length" {
		return true
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		return true
	}

	return self._stash.canPut(name)
}

func (self *_arrayStash) put(name string, value Value) {
	// length
	if name == "length" {
		value := uint(toUint32(value))
		length := uint(len(self.valueArray))
		if value > length {
			valueArray := make([]Value, value)
			copy(valueArray, self.valueArray)
			self.valueArray = valueArray
		} else if value < length {
			self.valueArray = self.valueArray[:value]
		}
		return
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		// May be able to do tricky stuff here
		// with checking cap() after len(), but not
		// sure if worth it
		if index < int64(len(self.valueArray)) {
			self.valueArray[index] = value
			return
		}
		valueArray := make([]Value, index+1)
		copy(valueArray, self.valueArray)
		valueArray[index] = value
		self.valueArray = valueArray
		return
	}

	self._stash.put(name, value)
}

func (self *_arrayStash) delete(name string) {
	// length
	if name == "length" {
		return
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		if index < int64(len(self.valueArray)) {
			self.valueArray[index] = emptyValue()
		}
	}
}
