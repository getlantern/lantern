package otto

import (
	"reflect"
)

func (runtime *_runtime) newGoStructObject(value reflect.Value) *_object {
	self := runtime.newObject()
	self.class = "Object" // TODO Should this be something else?
	self.stash = newGoStructStash(value, self.stash)
	return self
}

type _goStructStash struct {
	value reflect.Value
	_stash
}

func newGoStructStash(value reflect.Value, stash _stash) *_goStructStash {
	if value.Kind() != reflect.Struct {
		dbgf("%/panic//%@: %v != reflect.Struct", value.Kind())
	}
	self := &_goStructStash{
		value:  value,
		_stash: stash,
	}
	return self
}

func (self _goStructStash) getValue(name string) reflect.Value {
	return self.value.FieldByName(name)
}

func (self _goStructStash) field(name string) (reflect.StructField, bool) {
	return self.value.Type().FieldByName(name)
}

func (self _goStructStash) setValue(name string, value Value) bool {
	field, exists := self.field(name)
	if !exists {
		return false
	}
	fieldValue := self.getValue(name)
	reflectValue, err := value.toReflectValue(field.Type.Kind())
	if err != nil {
		panic(err)
	}
	fieldValue.Set(reflectValue)
	return true
}

// read

func (self *_goStructStash) test(name string) bool {
	value := self.getValue(name)
	if value.IsValid() {
		return true
	}
	return self._stash.test(name)
}

func (self *_goStructStash) get(name string) Value {
	value := self.getValue(name)
	if value.IsValid() {
		return toValue(value)
	}

	return self._stash.get(name)
}

func (self *_goStructStash) property(name string) *_property {
	value := self.getValue(name)
	if value.IsValid() {
		return &_property{
			toValue(value),
			0111, // +Write +Enumerate +Configure
		}
	}

	return self._stash.property(name)
}

func (self *_goStructStash) enumerate(each func(string)) {
	count := self.value.NumField()
	type_ := self.value.Type()
	for index := 0; index < count; index++ {
		each(type_.Field(index).Name)
	}

	self._stash.enumerate(each)
}

// write

func (self *_goStructStash) canPut(name string) bool {
	value := self.getValue(name)
	if value.IsValid() {
		return true
	}

	return self._stash.canPut(name)
}

func (self *_goStructStash) put(name string, value Value) {
	if self.setValue(name, value) {
		return
	}

	self._stash.put(name, value)
}

func (self *_goStructStash) delete(name string) {
	if _, exists := self.field(name); exists {
		return
	}

	self._stash.delete(name)
}
