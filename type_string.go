package otto

import (
	"strconv"
	"unicode/utf16"
)

type _stringObject struct {
	value   Value
	value16 []uint16
}

func (runtime *_runtime) newStringObject(value Value) *_object {
	value = toValue_string(toString(value))
	value16 := utf16Of(value.value.(string))

	self := runtime.newClassObject("String")
	self.defineProperty("length", toValue_int(len(value16)), 0, false)
	self.objectClass = _classString
	self.value = _stringObject{
		value:   value,
		value16: value16,
	}
	return self
}

func (self *_object) stringValue() (string, _stringObject) {
	value, valid := self.value.(_stringObject)
	if valid {
		return value.value.value.(string), value
	}
	return "", _stringObject{}
}

func (self *_object) stringValue16() []uint16 {
	_, value := self.stringValue()
	return value.value16
}

func utf16Of(value string) []uint16 {
	return utf16.Encode([]rune(value))
}

func stringEnumerate(self *_object, all bool, each func(string) bool) {
	length := len(self.stringValue16())
	for index := 0; index < length; index += 1 {
		if !each(strconv.FormatInt(int64(index), 10)) {
			return
		}
	}
	objectEnumerate(self, all, each)
}

func stringGetOwnProperty(self *_object, name string) *_property {
	if property := objectGetOwnProperty(self, name); property != nil {
		return property
	}
	index := stringToArrayIndex(name)
	if index >= 0 {
		value16 := self.stringValue16()
		if index < int64(len(value16)) {
			return &_property{toValue_string(string(value16[index])), 0}
		}
	}
	return nil
}
