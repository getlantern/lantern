package otto

import (
	"reflect"
	"strconv"
)

func (runtime *_runtime) newGoArrayObject(value reflect.Value) *_object {
	self := runtime.newObject()
	self.class = "Array" // TODO Should this be something else?
	self.stash = newGoArrayStash(value, self.stash)
	return self
}

type _goArrayStash struct {
	value        reflect.Value
	writable     bool
	propertyMode _propertyMode
	_stash
}

func newGoArrayStash(value reflect.Value, stash _stash) *_goArrayStash {
	propertyMode := _propertyMode(0111)
	writable := true
	switch value.Kind() {
	case reflect.Slice:
	case reflect.Array:
		// TODO We need SliceOf to exists (go1.1)
		// TODO Mark as unwritable for now
		propertyMode = 0010
		writable = false
	default:
		dbgf("%/panic//%@: %v != reflect.Slice", value.Kind())
	}
	self := &_goArrayStash{
		value:        value,
		writable:     writable,
		propertyMode: propertyMode,
		_stash:       stash,
	}
	return self
}

func (self _goArrayStash) getValue(index int) (reflect.Value, bool) {
	if index < self.value.Len() {
		return self.value.Index(index), true
	}
	return reflect.Value{}, false
}

func (self _goArrayStash) setValue(index int, value Value) {
	indexValue, exists := self.getValue(index)
	if !exists {
		return
	}
	reflectValue, err := value.toReflectValue(self.value.Type().Elem().Kind())
	if err != nil {
		panic(err)
	}
	indexValue.Set(reflectValue)
}

// read

func (self *_goArrayStash) test(name string) bool {
	// length
	if name == "length" {
		return true
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		_, exists := self.getValue(int(index))
		return exists
	}

	return self._stash.test(name)
}

func (self *_goArrayStash) get(name string) Value {
	// length
	if name == "length" {
		return toValue(self.value.Len())
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		value, exists := self.getValue(int(index))
		if !exists {
			return UndefinedValue()
		}
		return toValue(value)
	}

	return self._stash.get(name)
}

func (self *_goArrayStash) property(name string) *_property {
	// length
	if name == "length" {
		return &_property{
			value: toValue(self.value.Len()),
			mode:  0000, // -Write -Enumerate -Configure
			// -Write is different from the standard Array
		}
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		value := UndefinedValue()
		reflectValue, exists := self.getValue(int(index))
		if exists {
			value = toValue(reflectValue)
		}
		return &_property{
			value: value,
			mode:  self.propertyMode, // If addressable or not
		}
	}

	return self._stash.property(name)
}

func (self *_goArrayStash) enumerate(each func(string)) {
	// .0, .1, .2, ...

	for index, length := 0, self.value.Len(); index < length; index++ {
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}

	self._stash.enumerate(each)
}

// write

func (self *_goArrayStash) canPut(name string) bool {
	// length
	if name == "length" {
		return false
	}

	// .0, .1, .2, ...
	index := int(stringToArrayIndex(name))
	if index >= 0 {
		if self.writable {
			length := self.value.Len()
			if index < length {
				return self.writable
			}
		}
		return false
	}

	return self._stash.canPut(name)
}

func (self *_goArrayStash) put(name string, value Value) {
	// length
	if name == "length" {
		return
	}

	// .0, .1, .2, ...
	index := int(stringToArrayIndex(name))
	if index >= 0 {
		if self.writable {
			length := self.value.Len()
			if index < length {
				self.setValue(index, value)
			}
		}
		return
	}

	self._stash.put(name, value)
}

func (self *_goArrayStash) delete(name string) {
	// length
	if name == "length" {
		return
	}

	// .0, .1, .2, ...
	index := int(stringToArrayIndex(name))
	if index >= 0 {
		if self.writable {
			length := self.value.Len()
			if index < length {
				indexValue, exists := self.getValue(index)
				if !exists {
					return
				}
				indexValue.Set(reflect.Zero(self.value.Type().Elem()))
			}
		}
		return
	}

	self._stash.delete(name)
}
