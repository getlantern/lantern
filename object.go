package otto

type _object struct {
	runtime *_runtime

	class     string
	prototype *_object

	stash _stash

	primitive *Value
	_Function *_functionObject
	_RegExp   *_regExpObject
	_Date     *_dateObject
}

func (self _object) extensible() bool {
	return self.stash.extensible()
}

func (self _object) primitiveValue() Value {
	return *self.primitive
}

func newObject(runtime *_runtime, class string) *_object {
	return &_object{
		runtime: runtime,

		class: class,

		stash: newObjectStash(true),
	}
}

// Delete

func (self *_object) delete(name string, throw bool) bool {
	property_ := self.getOwnProperty(name)
	if property_ == nil {
		return true
	}
	if property_.configurable() {
		self.stash.delete(name)
		return true
	}
	return typeErrorResult(throw)
}

// 8.12

// 8.12.1
func (self *_object) getOwnProperty(name string) *_property {
	// Return a _copy_ of the property
	property := self.stash.property(name)
	if property == nil {
		return nil
	}
	{
		property := *property
		return &property
	}
}

// 8.12.2
func (self *_object) getProperty(name string) *_property {
	for object := self; object != nil; object = object.prototype {
		// Despite being a pointer, this property is always a copy
		property := object.stash.property(name)
		if property != nil {
			return property
		}
	}

	return nil
}

// 8.12.3
func (self *_object) get(name string) Value {
	object := self
	for object != nil {
		if object.stash.test(name) {
			return object.stash.get(name)
		}
		object = object.prototype
	}
	return UndefinedValue()
}

// 8.12.4
func (self *_object) canPut(name string) bool {

	property := self.stash.property(name)
	if property != nil {
		switch value := property.value.(type) {
		case Value:
			return property.writable()
		case _propertyGetSet:
			return value[1] != nil
		default:
			panic(hereBeDragons())
		}
	}

	if self.prototype != nil {
		property = self.prototype.getProperty(name)
	}
	if property == nil {
		return self.extensible()
	}

	switch value := property.value.(type) {
	case Value:
		if !self.extensible() {
			return false
		}
		return property.writable()
	case _propertyGetSet:
		return value[1] != nil
	}

	panic(hereBeDragons())
}

// 8.12.5
func (self *_object) put(name string, value Value, throw bool) {
	if !self.canPut(name) {
		typeErrorResult(throw)
		return
	}
	self.stash.put(name, value)
}

// Like put, but bypass checking of prototype property presence
func (self *_object) set(name string, value Value, throw bool) {
	if !self.stash.canPut(name) {
		typeErrorResult(throw)
		return
	}
	self.stash.put(name, value)
}

// 8.12.6
func (self *_object) hasProperty(name string) bool {
	for object := self; object != nil; object = object.prototype {
		if object.stash.test(name) {
			return true
		}
	}

	return false
}

type _defaultValueHint int

const (
	defaultValueNoHint _defaultValueHint = iota
	defaultValueHintString
	defaultValueHintNumber
)

// 8.12.8
func (self *_object) DefaultValue(hint _defaultValueHint) Value {
	if hint == defaultValueNoHint {
		if self._Date != nil {
			// Date exception
			hint = defaultValueHintString
		} else {
			hint = defaultValueHintNumber
		}
	}
	methodSequence := []string{"valueOf", "toString"}
	if hint == defaultValueHintString {
		methodSequence = []string{"toString", "valueOf"}
	}
	for _, methodName := range methodSequence {
		method := self.get(methodName)
		if method.isCallable() {
			result := method._object().Call(toValue(self))
			if result.IsPrimitive() {
				return result
			}
		}
	}

	panic(newTypeError())
	return UndefinedValue()
}

func (self *_object) String() string {
	return toString(self.DefaultValue(defaultValueHintString))
}

// 8.12.9
func (self *_object) defineOwnProperty(name string, descriptor _property, throw bool) bool {
	property, exists := self.stash.index(name)
	{
		if !exists {
			if !self.extensible() {
				goto Reject
			}
			self.stash.defineProperty(name, descriptor.value, descriptor.mode)
			return true
		}
		if descriptor.isEmpty() {
			return true
		}

		// TODO Per 8.12.9.6 - We should shortcut here (returning true) if
		// the current and new (define) properties are the same

		// TODO Use the other stash methods so we write to special properties properly?

		configurable := property.configurable()
		if !configurable {
			if descriptor.configurable() {
				goto Reject
			}
			// Test that, if enumerable is set on the property descriptor, then it should
			// be the same as the existing property
			if descriptor.mode&0020 == 0 && descriptor.enumerable() != property.enumerable() {
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
				property.mode = property.mode & ^propertyMode_write
				property.value = interface_
			} else {
				property.mode |= propertyMode_write
				property.value = interface_
			}
		} else if isDataDescriptor && descriptor.isDataDescriptor() {
			if !configurable {
				if property.writable() != descriptor.writable() {
					goto Reject
				} else if !sameValue(value, descriptor.value.(Value)) {
					goto Reject
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
		self.stash.defineProperty(name, descriptor.value, descriptor.mode)
		return true
	}
Reject:
	if throw {
		panic(newTypeError())
	}
	return false
}

func (self *_object) hasOwnProperty(name string) bool {
	return self.stash.test(name)
}

//func (self *_object) Define(definition... interface{}) {
//    property_ := _property{ Mode: 0111 }.toDefineProperty()
//    length := 0
//    nativeClass_ := "native" + self.Class + "_"

//    for index := 0; index < len(definition); index++ {
//        value := definition[index]
//        switch value := value.(type) {
//        case _propertyMode:
//            property_ = _property{Mode: value}.toDefineProperty()
//        case string:
//            name := value
//            length = 0
//            index += 1
//REPEAT:		{
//                value := definition[index]
//                switch value := value.(type) {
//                    case func(FunctionCall) Value: {
//                        value := self.runtime.newNativeFunction(value, length, nativeClass_ + name)
//                        property_.Value = toValue(value)
//                        self.DefineOwnProperty(name, property_, false)
//                    }
//                    case *_object:
//                        property_.Value = toValue(value)
//                        self.DefineOwnProperty(name, property_, false)
//                    case Value:
//                        property_.Value = value
//                        self.DefineOwnProperty(name, property_, false)
//                    case int:
//                        length = value
//                        index += 1
//                        goto REPEAT
//                    default:
//                        panic(hereBeDragons())
//                }
//            }
//        }
//    }
//}

func (self *_object) write(definition ...interface{}) {
	mode := _propertyMode(0111)
	length := 0
	nativeClass_ := "native" + self.class + "_"

	for index := 0; index < len(definition); index++ {
		value := definition[index]
		switch value := value.(type) {
		case _propertyMode:
			mode = value
		case string:
			name := value
			length = 0
			index += 1
		REPEAT:
			{
				value := definition[index]
				switch value := value.(type) {
				case func(FunctionCall) Value:
					{
						value := self.runtime.newNativeFunction(value, length, nativeClass_+name)
						self.stash.set(name, toValue(value), mode)
					}
				case *_object:
					self.stash.set(name, toValue(value), mode)
				case Value:
					self.stash.set(name, value, mode)
				case int:
					length = value
					index += 1
					goto REPEAT
				default:
					panic(hereBeDragons())
				}
			}
		}
	}
}

func (self *_object) enumerate(each func(string)) {
	self.stash.enumerate(each)
}
