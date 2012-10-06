package otto

type _object struct {
	runtime *_runtime

	Class string
	Extensible bool
    Prototype *_object

	_propertyStash _stash

	Primitive *Value
	Function *_functionObject
	RegExp *_regExpObject
	Date *_dateObject
}

func (self _object) PrimitiveValue() Value {
	return *self.Primitive
}

func newObject(runtime *_runtime, class string) *_object {
	return &_object{
		runtime: runtime,

		Class: class,
		Extensible: true,

		_propertyStash: newPropertyStash(true),
	}
}

// Write

func (self *_object) WriteValue(name string, value Value, throw bool) {
	canWrite := self._propertyStash.CanWrite(name)
	if !canWrite {
		typeErrorResult(throw)
		return
	}
	self._propertyStash.Write(name, value)
}

// Delete

func (self *_object) Delete(name string, throw bool) bool {
	property_ := self.GetOwnProperty(name)
	if property_ == nil {
		return true
	}
	if property_.CanConfigure() {
		self._propertyStash.Delete(name)
		return true
	}
	return typeErrorResult(throw)
}

// Get

func (self *_object) GetValue(name string) Value {
	return self.Get(name)
}

// 8.12

// 8.12.1
func (self *_object) GetOwnProperty(name string) *_property {
	// Return a _copy_ of the property
	property := self._propertyStash.property(name)
	if property == nil {
		return nil
	}
	{
		property := *property
		return &property
	}
}

func (self *_object) getProperty(name string) *_property {

	for object := self; object != nil; object = object.Prototype {
		property := object._propertyStash.property(name)
		if property != nil {
			return property
		}
	}

	return nil
}

// 8.12.2
func (self *_object) GetProperty(name string) *_property {
	property := self.getProperty(name)
	if property != nil {
		property = property.Copy()
	}
	return property
}

// 8.12.3
func (self *_object) Get(name string) Value {
	object := self
	for object != nil {
		if object._propertyStash.CanRead(name) {
			return object._propertyStash.Read(name)
		}
		object = object.Prototype
	}
	return UndefinedValue()
}

// 8.12.4
func (self *_object) CanPut(name string) bool {

	property := self._propertyStash.property(name)
	if property != nil {
		switch value := property.Value.(type) {
		case Value:
			return property.CanWrite()
		case _propertyGetSet:
			return value[1] != nil
		default:
			panic(hereBeDragons())
		}
	}

	if self.Prototype != nil {
		property = self.Prototype.getProperty(name)
	}
	if property == nil {
		return self.Extensible
	}

	switch value := property.Value.(type) {
	case Value:
		if !self.Extensible {
			return false
		}
		return property.CanWrite()
	case _propertyGetSet:
		return value[1] != nil
	}

	panic(hereBeDragons())
}

// 8.12.5
func (self *_object) Put(name string, value Value, throw bool) {
	if !self.CanPut(name) {
		typeErrorResult(throw)
		return
	}
	self._propertyStash.Write(name, value)
}

// 8.12.6
func (self *_object) HasProperty(name string) bool {
	for object := self; object != nil; object = object.Prototype {
		if object._propertyStash.CanRead(name) {
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
        hint = defaultValueHintNumber
    }
    methodSequence := []string{"valueOf", "toString"}
    if (hint == defaultValueHintString) {
        methodSequence = []string{"toString", "valueOf"}
    }
    for _, methodName := range methodSequence {
        method := self.Get(methodName)
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
func (self *_object) DefineOwnProperty(name string, _defineProperty _defineProperty, throw bool) bool {
	return self._propertyStash.Define(name, _defineProperty)
}

func (self *_object) DefineOwnValueProperty(name string, value Value, mode _propertyMode, throw bool) bool {
	return self._propertyStash.Define(name, _property{Value: value, Mode: mode}.toDefineProperty())
}

func (self *_object) HasOwnProperty(name string) bool {
	return self._propertyStash.CanRead(name)
}

func (self *_object) Define(nameAndValue... interface{}) {
	property_ := _property{Mode: propertyModeWriteEnumerateConfigure}.toDefineProperty()
	length := 0
	signature := _functionSignature("")

	for index := 0; index < len(nameAndValue); index++ {
		value := nameAndValue[index]
		switch value := value.(type) {
		case _functionSignature:
			signature = value
		case _propertyMode:
			property_ = _property{Mode: value}.toDefineProperty()
		case string:
			name := value
			length = 0
			index += 1
REPEAT:		{
				value := nameAndValue[index]
				switch value := value.(type) {
					case func(FunctionCall) Value: {
						value := self.runtime.newNativeFunction(value, length)
						value.Function.Call.Sign(signature)
						property_.Value = toValue(value)
						self.DefineOwnProperty(name, property_, false)
					}
					case *_object:
						property_.Value = toValue(value)
						self.DefineOwnProperty(name, property_, false)
					case Value:
						property_.Value = value
						self.DefineOwnProperty(name, property_, false)
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

func (self *_object) define(nameAndValue... interface{}) {
	mode := propertyModeWriteEnumerateConfigure
	length := 0
	signature := _functionSignature("")

	stash := map[string]_valueProperty{}

	for index := 0; index < len(nameAndValue); index++ {
		value := nameAndValue[index]
		switch value := value.(type) {
		case _functionSignature:
			signature = value
		case _propertyMode:
			mode = value
		case string:
			name := value
			length = 0
			index += 1
REPEAT:		{
				value := nameAndValue[index]
				switch value := value.(type) {
					case func(FunctionCall) Value: {
						value := self.runtime.newNativeFunction(value, length)
						value.Function.Call.Sign(signature)
						stash[name] = _valueProperty{ toValue(value), mode }
					}
					case *_object:
						stash[name] = _valueProperty{ toValue(value), mode }
					case Value:
						stash[name] = _valueProperty{ value, mode }
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

	self._propertyStash.writeValuePropertyMap(stash)
}

func (self *_object) Enumerate(each func(string)) {
	self._propertyStash.Enumerate(each)
}
