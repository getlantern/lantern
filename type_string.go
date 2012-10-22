package otto

import (
	"strconv"
)

func (runtime *_runtime) newStringObject(value Value) *_object {
	self := runtime.newPrimitiveObject("String", toValue(toString(value)))
	self.stash = newStringStash(toString(value), self.stash)
	return self
}

type _stringStash struct {
	value string
	_stash
}

func newStringStash(value string, stash _stash) *_stringStash {
	self := &_stringStash{
		value,
		stash,
	}
	return self
}

func (self *_stringStash) test(name string) bool {
	// .length
	if name == "length" {
		return true
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.value)) {
		return true
	}

	return self._stash.test(name)
}

func (self *_stringStash) get(name string) Value {
	// .length
	if name == "length" {
		return toValue(len(string(self.value)))
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.value)) {
		return toValue(string(self.value[index]))
	}

	return self._stash.get(name)
}

func (self *_stringStash) property(name string) *_property {
	// .length
	if name == "length" {
		return &_property{
			toValue(len(string(self.value))),
			0, // -Write -Enumerate -Configure
		}
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.value)) {
		return &_property{
			toValue(string(self.value[index])),
			0, // -Write -Enumerate -Configure
		}
	}

	return self._stash.property(name)
}

func (self *_stringStash) enumerate(each func(string)) {
	// .0, .1, .2, ...
	for index, _ := range self.value {
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}
	self._stash.enumerate(each)
}
