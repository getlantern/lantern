package otto

import (
	"reflect"
)

func (runtime *_runtime) newGoStructObject(value reflect.Value) *_object {
	self := runtime.newObject()
	self.class = "Object" // TODO Should this be something else?
	self.objectClass = _classGoStruct
	self.value = _newGoStructObject(value)
	return self
}

type _goStructObject struct {
	value reflect.Value
}

func _newGoStructObject(value reflect.Value) *_goStructObject {
	if reflect.Indirect(value).Kind() != reflect.Struct {
		dbgf("%/panic//%@: %v != reflect.Struct", value.Kind())
	}
	self := &_goStructObject{
		value: value,
	}
	return self
}

func (self _goStructObject) getValue(name string) reflect.Value {
	return reflect.Indirect(self.value).FieldByName(name)
}

func (self _goStructObject) field(name string) (reflect.StructField, bool) {
	return reflect.Indirect(self.value).Type().FieldByName(name)
}

func (self _goStructObject) setValue(name string, value Value) bool {
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

func goStructGetOwnProperty(self *_object, name string) *_property {
	object := self.value.(*_goStructObject)
	value := object.getValue(name)
	if value.IsValid() {
		return &_property{self.runtime.toValue(value.Interface()), 0110}
	}

	return objectGetOwnProperty(self, name)
}

func goStructEnumerate(self *_object, each func(string)) {
	object := self.value.(*_goStructObject)
	count := object.value.NumField()
	type_ := object.value.Type()
	for index := 0; index < count; index++ {
		each(type_.Field(index).Name)
	}

	objectEnumerate(self, each)
}

func goStructCanPut(self *_object, name string) bool {
	object := self.value.(*_goStructObject)
	value := object.getValue(name)
	if value.IsValid() {
		return true
	}

	return objectCanPut(self, name)
}

func goStructPut(self *_object, name string, value Value, throw bool) {
	object := self.value.(*_goStructObject)
	if object.setValue(name, value) {
		return
	}

	objectPut(self, name, value, throw)
}
