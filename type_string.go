package otto

import (
	"strconv"
	"unicode/utf16"
)

func (runtime *_runtime) newStringObject(value Value) *_object {
	self := runtime.newPrimitiveObject("String", toValue(toString(value)))
	self.stash = newStringStash(toString(value), self.stash)
	return self
}

type _stringStash struct {
	value   string
	value16 []uint16
	_stash
}

func newStringStash(value string, stash _stash) *_stringStash {
	self := &_stringStash{
		value:   value,
		value16: utf16.Encode([]rune(value)),
		_stash:  stash,
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
	if index >= 0 && index < int64(len(self.value16)) {
		return true
	}

	return self._stash.test(name)
}

func (self *_stringStash) get(name string) Value {
	// .length
	if name == "length" {
		return toValue(len(self.value16))
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.value16)) {
		return toValue(string(self.value16[index]))
	}

	return self._stash.get(name)
}

func (self *_stringStash) property(name string) *_property {
	// .length
	if name == "length" {
		return &_property{
			toValue(len(self.value16)),
			0, // -Write -Enumerate -Configure
		}
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 && index < int64(len(self.value16)) {
		return &_property{
			toValue(string(self.value16[index])),
			0, // -Write -Enumerate -Configure
		}
	}

	return self._stash.property(name)
}

func (self *_stringStash) enumerate(each func(string)) {
	// .0, .1, .2, ...
	for index, _ := range self.value16 {
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}
	self._stash.enumerate(each)
}
