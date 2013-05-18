package otto

type _objectClass struct {
	getOwnProperty    func(*_object, string) *_property
	getProperty       func(*_object, string) *_property
	get               func(*_object, string) Value
	canPut            func(*_object, string) bool
	put               func(*_object, string, Value, bool)
	hasProperty       func(*_object, string) bool
	hasOwnProperty    func(*_object, string) bool
	defineOwnProperty func(*_object, string, _property, bool) bool
	delete            func(*_object, string, bool) bool
	enumerate         func(*_object, func(string))
}

func objectEnumerate(self *_object, each func(string)) {
	for _, name := range self.propertyOrder {
		if self.property[name].enumerable() {
			each(name)
		}
	}
}

var (
	_classObject,
	_classArray,
	_classString,
	_classArguments,
	_classGoStruct,
	_classGoMap,
	_classGoArray,
	_ *_objectClass
)

func init() {
	_classObject = &_objectClass{
		objectGetOwnProperty,
		objectGetProperty,
		objectGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		objectDefineOwnProperty,
		objectDelete,
		objectEnumerate,
	}

	_classArray = &_objectClass{
		objectGetOwnProperty,
		objectGetProperty,
		objectGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		arrayDefineOwnProperty,
		objectDelete,
		objectEnumerate,
	}

	_classString = &_objectClass{
		stringGetOwnProperty,
		objectGetProperty,
		objectGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		objectDefineOwnProperty,
		objectDelete,
		stringEnumerate,
	}

	_classArguments = &_objectClass{
		argumentsGetOwnProperty,
		objectGetProperty,
		argumentsGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		argumentsDefineOwnProperty,
		argumentsDelete,
		objectEnumerate,
	}

	_classGoStruct = &_objectClass{
		goStructGetOwnProperty,
		objectGetProperty,
		objectGet,
		goStructCanPut,
		goStructPut,
		objectHasProperty,
		objectHasOwnProperty,
		objectDefineOwnProperty,
		objectDelete,
		goStructEnumerate,
	}

	_classGoMap = &_objectClass{
		goMapGetOwnProperty,
		objectGetProperty,
		objectGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		goMapDefineOwnProperty,
		goMapDelete,
		goMapEnumerate,
	}

	_classGoArray = &_objectClass{
		goArrayGetOwnProperty,
		objectGetProperty,
		objectGet,
		objectCanPut,
		objectPut,
		objectHasProperty,
		objectHasOwnProperty,
		goArrayDefineOwnProperty,
		goArrayDelete,
		goArrayEnumerate,
	}
}

// Allons-y

// 8.12.1
func objectGetOwnProperty(self *_object, name string) *_property {
	// Return a _copy_ of the property
	property, exists := self._read(name)
	if !exists {
		return nil
	}
	return &property
}

// 8.12.2
func objectGetProperty(self *_object, name string) *_property {
	property := self.getOwnProperty(name)
	if property != nil {
		return property
	}
	if self.prototype != nil {
		return self.prototype.getProperty(name)
	}
	return nil
}

// 8.12.3
func objectGet(self *_object, name string) Value {
	property := self.getProperty(name)
	if property != nil {
		return property.value.(Value)
	}
	return UndefinedValue()
}

// 8.12.4
func objectCanPut(self *_object, name string) bool {

	property := self.getOwnProperty(name)
	if property != nil {
		switch value := property.value.(type) {
		case Value:
			return property.writable()
		case _propertyGetSet:
			return value[1] != nil
		default:
			panic(newTypeError())
		}
	}

	if self.prototype == nil {
		return self.extensible
	}

	property = self.prototype.getOwnProperty(name)
	if property == nil {
		return self.extensible
	}

	switch value := property.value.(type) {
	case Value:
		if !self.extensible {
			return false
		}
		return property.writable()
	case _propertyGetSet:
		return value[1] != nil
	default:
		panic(newTypeError())
	}

	return false
}

// 8.12.5
func objectPut(self *_object, name string, value Value, throw bool) {
	if !self.canPut(name) {
		typeErrorResult(throw)
		return
	}
	// TODO Shortcut?
	property := self.getOwnProperty(name)
	if property == nil {
		self.defineProperty(name, value, 0111, throw)
	} else {
		property.value = value
		self.defineOwnProperty(name, *property, throw)
	}
}

// 8.12.6
func objectHasProperty(self *_object, name string) bool {
	return self.getProperty(name) != nil
}

func objectHasOwnProperty(self *_object, name string) bool {
	return self.getOwnProperty(name) != nil
}

// 8.12.9
func objectDefineOwnProperty(self *_object, name string, descriptor _property, throw bool) bool {
	property, exists := self._read(name)
	{
		if !exists {
			if !self.extensible {
				goto Reject
			}
			self._write(name, descriptor.value, descriptor.mode)
			return true
		}
		if descriptor.isEmpty() {
			return true
		}

		// TODO Per 8.12.9.6 - We should shortcut here (returning true) if
		// the current and new (define) properties are the same

		configurable := property.configurable()
		if !configurable {
			if descriptor.configurable() {
				goto Reject
			}
			// Test that, if enumerable is set on the property descriptor, then it should
			// be the same as the existing property
			if descriptor.enumerateSet() && descriptor.enumerable() != property.enumerable() {
				return false
			}
		}
		value, isDataDescriptor := property.value.(Value)
		getSet, _ := property.value.(_propertyGetSet)
		if descriptor.isGenericDescriptor() {
			// GenericDescriptor
		} else if isDataDescriptor != descriptor.isDataDescriptor() {
			var interface_ interface{}
			if isDataDescriptor {
				property.writeOff()
				property.value = interface_
			} else {
				property.writeOn()
				property.value = interface_
			}
		} else if isDataDescriptor && descriptor.isDataDescriptor() {
			if !configurable {
				if !property.writable() && descriptor.writable() {
					goto Reject
				}
				if !property.writable() {
					if !sameValue(value, descriptor.value.(Value)) {
						goto Reject
					}
				}
			}
		} else {
			if !configurable {
				defineGetSet, _ := descriptor.value.(_propertyGetSet)
				if getSet[0] != defineGetSet[0] || getSet[1] != defineGetSet[1] {
					goto Reject
				}
			}
		}
		self._write(name, descriptor.value, descriptor.mode)
		return true
	}
Reject:
	if throw {
		panic(newTypeError())
	}
	return false
}

func objectDelete(self *_object, name string, throw bool) bool {
	property_ := self.getOwnProperty(name)
	if property_ == nil {
		return true
	}
	if property_.configurable() {
		self._delete(name)
		return true
	}
	return typeErrorResult(throw)
}
