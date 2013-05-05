package otto

import (
	"reflect"
	"strconv"
)

func (runtime *_runtime) newGoArrayObject(value reflect.Value) *_object {
	self := runtime.newObject()
	self.class = "GoArray"
	self.objectClass = _classGoArray
	self.value = _newGoArrayObject(value)
	return self
}

type _goArrayObject struct {
	value        reflect.Value
	writable     bool
	propertyMode _propertyMode
}

func _newGoArrayObject(value reflect.Value) *_goArrayObject {
	propertyMode := _propertyMode(0110)
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
	self := &_goArrayObject{
		value:        value,
		writable:     writable,
		propertyMode: propertyMode,
	}
	return self
}

func (self _goArrayObject) getValue(index int) (reflect.Value, bool) {
	if index < self.value.Len() {
		return self.value.Index(index), true
	}
	return reflect.Value{}, false
}

func (self _goArrayObject) setValue(index int, value Value) {
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

func goArrayGetOwnProperty(self *_object, name string) *_property {
	object := self.value.(*_goArrayObject)
	// length
	if name == "length" {
		return &_property{
			value: toValue(object.value.Len()),
			mode:  0,
		}
	}

	// .0, .1, .2, ...
	index := stringToArrayIndex(name)
	if index >= 0 {
		value := UndefinedValue()
		reflectValue, exists := object.getValue(int(index))
		if exists {
			value = self.runtime.toValue(reflectValue.Interface())
		}
		return &_property{
			value: value,
			mode:  object.propertyMode, // If addressable or not
		}
	}

	return objectGetOwnProperty(self, name)
}

func goArrayEnumerate(self *_object, each func(string)) {
	object := self.value.(*_goArrayObject)
	// .0, .1, .2, ...

	for index, length := 0, object.value.Len(); index < length; index++ {
		name := strconv.FormatInt(int64(index), 10)
		each(name)
	}

	objectEnumerate(self, each)
}

func goArrayDefineOwnProperty(self *_object, name string, descriptor _property, throw bool) bool {
	if name == "length" {
		return false
	} else if index := stringToArrayIndex(name); index >= 0 {
		object := self.value.(*_goArrayObject)
		if int(index) >= object.value.Len() {
			return false
		}
		object.setValue(int(index), descriptor.value.(Value))
		return true
	}
	return objectDefineOwnProperty(self, name, descriptor, throw)
}

func goArrayDelete(self *_object, name string, throw bool) bool {
	object := self.value.(*_goArrayObject)
	// length
	if name == "length" {
		return false
	}

	// .0, .1, .2, ...
	index := int(stringToArrayIndex(name))
	if index >= 0 {
		if object.writable {
			length := object.value.Len()
			if index < length {
				indexValue, exists := object.getValue(index)
				if !exists {
					return false
				}
				indexValue.Set(reflect.Zero(object.value.Type().Elem()))
				return true
			}
		}
		return false
	}

	return self.delete(name, throw)
}
