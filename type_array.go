package otto

import (
	"strconv"
)

func (runtime *_runtime) newArrayObject(length uint32) *_object {
	self := runtime.newObject()
	self.class = "Array"
	self.defineProperty("length", toValue(length), 0100, false)
	self.objectClass = _classArray
	return self
}

func isArray(object *_object) bool {
	return object != nil && (object.class == "Array" || object.class == "GoArray")
}

func arrayDefineOwnProperty(self *_object, name string, descriptor _property, throw bool) bool {
	lengthProperty := self.getOwnProperty("length")
	lengthValue, valid := lengthProperty.value.(Value)
	if !valid {
		return objectDefineOwnProperty(self, name, descriptor, throw)
	}
	length := lengthValue.value.(uint32)
	if name == "length" {
		if descriptor.value == nil {
			return objectDefineOwnProperty(self, name, descriptor, throw)
		}
		newLength := toUint32(descriptor.value.(Value))
		descriptor.value = toValue(newLength)
		if newLength > length {
			return objectDefineOwnProperty(self, name, descriptor, throw)
		}
		if !lengthProperty.writable() {
			goto Reject
		}
		newWritable := true
		if descriptor.mode&0700 == 0 {
			// If writable is off
			newWritable = false
			descriptor.mode |= 0100
		}
		if !objectDefineOwnProperty(self, name, descriptor, throw) {
			return false
		}
		for newLength < length {
			length -= 1
			if !self.delete(strconv.FormatInt(int64(length), 10), false) {
				descriptor.value = toValue(length + 1)
				if !newWritable {
					descriptor.mode &= 0077
				}
				objectDefineOwnProperty(self, name, descriptor, false)
				goto Reject
			}
		}
		if !newWritable {
			descriptor.mode &= 0077
			objectDefineOwnProperty(self, name, descriptor, false)
		}
	} else if index := stringToArrayIndex(name); index >= 0 {
		index := uint32(index)
		if index >= length && !lengthProperty.writable() {
			goto Reject
		}
		if !objectDefineOwnProperty(self, name, descriptor, false) {
			goto Reject
		}
		if index >= length {
			lengthProperty.value = toValue(index + 1)
			objectDefineOwnProperty(self, "length", *lengthProperty, false)
			return true
		}
	}
	return objectDefineOwnProperty(self, name, descriptor, throw)
Reject:
	if throw {
		panic(newTypeError())
	}
	return false
}
