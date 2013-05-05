package otto

// _environment

type _environment interface {
	HasBinding(string) bool

	CreateMutableBinding(string, bool)
	SetMutableBinding(string, Value, bool)
	// SetMutableBinding with Lazy CreateMutableBinding(..., true)
	SetValue(string, Value, bool)

	GetBindingValue(string, bool) Value
	GetValue(string, bool) Value // GetBindingValue
	DeleteBinding(string) bool
	ImplicitThisValue() *_object

	Outer() _environment

	newReference(string, bool) _reference
}

// _functionEnvironment

type _functionEnvironment struct {
	_declarativeEnvironment
	arguments           *_object
	indexOfArgumentName map[string]string
}

func (runtime *_runtime) newFunctionEnvironment(outer _environment) *_functionEnvironment {
	return &_functionEnvironment{
		_declarativeEnvironment: _declarativeEnvironment{
			runtime:  runtime,
			outer:    outer,
			property: map[string]*_declarativeProperty{},
		},
	}
}

//func (self *_functionEnvironment) newReference(name string, strict bool) _reference {
//    index, exists := self.indexOfArgumentName[name]
//    if !exists {
//        return self._declarativeEnvironment.newReference(name, strict)
//    }
//    return newArgumentReference(self.arguments, index, strict)
//}

//func (self *_functionEnvironment) HasBinding(name string) bool {
//    _, exists := self.indexOfArgumentName[name]
//    if exists {
//        return true
//    }
//    return self._declarativeEnvironment.HasBinding(name)
//}

// _objectEnvironment

type _objectEnvironment struct {
	runtime     *_runtime
	outer       _environment
	Object      *_object
	ProvideThis bool
}

func (runtime *_runtime) newObjectEnvironment(object *_object, outer _environment) *_objectEnvironment {
	if object == nil {
		object = runtime.newBaseObject()
	}
	return &_objectEnvironment{
		runtime: runtime,
		outer:   outer,
		Object:  object,
	}
}

func (self *_objectEnvironment) HasBinding(name string) bool {
	return self.Object.hasProperty(name)
}

func (self *_objectEnvironment) CreateMutableBinding(name string, deletable bool) {
	if self.Object.hasProperty(name) {
		panic(hereBeDragons())
	}
	mode := _propertyMode(0111)
	if !deletable {
		mode = _propertyMode(0110)
	}
	// TODO False?
	self.Object.defineProperty(name, UndefinedValue(), mode, false)
}

func (self *_objectEnvironment) SetMutableBinding(name string, value Value, strict bool) {
	self.Object.put(name, value, strict)
}

func (self *_objectEnvironment) SetValue(name string, value Value, throw bool) {
	if !self.HasBinding(name) {
		self.CreateMutableBinding(name, true) // Configureable by default
	}
	self.SetMutableBinding(name, value, throw)
}

func (self *_objectEnvironment) GetBindingValue(name string, strict bool) Value {
	if self.Object.hasProperty(name) {
		return self.Object.get(name)
	}
	if strict {
		panic(newReferenceError("Not Defined", name))
	}
	return UndefinedValue()
}

func (self *_objectEnvironment) GetValue(name string, throw bool) Value {
	return self.GetBindingValue(name, throw)
}

func (self *_objectEnvironment) DeleteBinding(name string) bool {
	return self.Object.delete(name, false)
}

func (self *_objectEnvironment) ImplicitThisValue() *_object {
	if self.ProvideThis {
		return self.Object
	}
	return nil
}

func (self *_objectEnvironment) Outer() _environment {
	return self.outer
}

func (self *_objectEnvironment) newReference(name string, strict bool) _reference {
	return newPropertyReference(self.Object, name, strict, nil)
}

// _declarativeEnvironment

func (runtime *_runtime) newDeclarativeEnvironment(outer _environment) *_declarativeEnvironment {
	return &_declarativeEnvironment{
		runtime:  runtime,
		outer:    outer,
		property: map[string]*_declarativeProperty{},
	}
}

type _declarativeProperty struct {
	value     Value
	mutable   bool
	deletable bool
}

type _declarativeEnvironment struct {
	runtime  *_runtime
	outer    _environment
	property map[string]*_declarativeProperty
}

func (self *_declarativeEnvironment) HasBinding(name string) bool {
	_, exists := self.property[name]
	return exists
}

func (self *_declarativeEnvironment) CreateMutableBinding(name string, deletable bool) {
	_, exists := self.property[name]
	if exists {
		panic(hereBeDragons())
	}
	self.property[name] = &_declarativeProperty{
		value:     UndefinedValue(),
		mutable:   true,
		deletable: deletable,
	}
}

func (self *_declarativeEnvironment) SetMutableBinding(name string, value Value, strict bool) {
	property := self.property[name]
	if property == nil {
		panic(hereBeDragons())
	}
	if property.mutable {
		property.value = value
	} else {
		typeErrorResult(strict)
	}
}

func (self *_declarativeEnvironment) SetValue(name string, value Value, throw bool) {
	if !self.HasBinding(name) {
		self.CreateMutableBinding(name, false) // NOT deletable by default
	}
	self.SetMutableBinding(name, value, throw)
}

func (self *_declarativeEnvironment) GetBindingValue(name string, strict bool) Value {
	property := self.property[name]
	if property == nil {
		panic(hereBeDragons())
	}
	if !property.mutable {
		// TODO If uninitialized...
	}
	return property.value
}

func (self *_declarativeEnvironment) GetValue(name string, throw bool) Value {
	return self.GetBindingValue(name, throw)
}

func (self *_declarativeEnvironment) DeleteBinding(name string) bool {
	property := self.property[name]
	if property == nil {
		delete(self.property, name)
		return false
	}
	if !property.deletable {
		return false
	}
	delete(self.property, name)
	return true
}

func (self *_declarativeEnvironment) ImplicitThisValue() *_object {
	return nil
}

func (self *_declarativeEnvironment) Outer() _environment {
	return self.outer
}

func (self *_declarativeEnvironment) newReference(name string, strict bool) _reference {
	return newEnvironmentReference(self, name, strict, nil)
}
