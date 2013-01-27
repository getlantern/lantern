package otto

import (
	"reflect"
)

func (runtime *_runtime) newGoMapObject(value reflect.Value) *_object {
	self := runtime.newObject()
	self.class = "Object" // TODO Should this be something else?
	self.stash = newGoMapStash(value, self.stash)
	return self
}

type _goMapStash struct {
	value     reflect.Value
	keyKind   reflect.Kind
	valueKind reflect.Kind
	_stash
}

func newGoMapStash(value reflect.Value, stash _stash) *_goMapStash {
	if value.Kind() != reflect.Map {
		dbgf("%/panic//%@: %v != reflect.Map", value.Kind())
	}
	self := &_goMapStash{
		value:     value,
		keyKind:   value.Type().Key().Kind(),
		valueKind: value.Type().Elem().Kind(),
		_stash:    stash,
	}
	return self
}

func (self _goMapStash) toKey(name string) reflect.Value {
	reflectValue, err := stringToReflectValue(name, self.keyKind)
	if err != nil {
		panic(err)
	}
	return reflectValue
}

func (self _goMapStash) toValue(value Value) reflect.Value {
	reflectValue, err := value.toReflectValue(self.valueKind)
	if err != nil {
		panic(err)
	}
	return reflectValue
}

// read

func (self *_goMapStash) test(name string) bool {
	value := self.value.MapIndex(self.toKey(name))
	if value.IsValid() {
		return true
	}
	return false
}

func (self *_goMapStash) get(name string) Value {
	value := self.value.MapIndex(self.toKey(name))
	if value.IsValid() {
		return toValue(value)
	}

	return UndefinedValue()
}

func (self *_goMapStash) property(name string) *_property {
	value := self.value.MapIndex(self.toKey(name))
	if value.IsValid() {
		return &_property{
			toValue(value),
			0111, // +Write +Enumerate +Configure
		}
	}

	return nil
}

func (self *_goMapStash) enumerate(each func(string)) {
	keys := self.value.MapKeys()
	for _, key := range keys {
		each(key.String())
	}
}

// write

func (self *_goMapStash) canPut(name string) bool {
	return true
}

func (self *_goMapStash) put(name string, value Value) {
	self.value.SetMapIndex(self.toKey(name), self.toValue(value))
}

func (self *_goMapStash) delete(name string) {
	// Setting a zero Value will delete the key
	self.value.SetMapIndex(self.toKey(name), reflect.Value{})
}
