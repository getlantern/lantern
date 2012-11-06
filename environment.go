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
	_objectEnvironment
	arguments *_object
	indexOfArgumentName map[string]string
}

func (runtime *_runtime) newFunctionEnvironment(outer _environment) *_functionEnvironment {
	return &_functionEnvironment{
		_objectEnvironment: _objectEnvironment{
			outer: outer,
			Object: runtime.newObject(),
		},
	}
}

func (self *_functionEnvironment) newReference(name string, strict bool) _reference {
	index, exists := self.indexOfArgumentName[name]
	if !exists {
		return self._objectEnvironment.newReference(name, strict)
	}
	return newArgumentReference(self.arguments, index, strict)
}

func (self *_functionEnvironment) HasBinding(name string) bool {
	_, exists := self.indexOfArgumentName[name]
	if exists {
		return true
	}
	return self.Object.hasProperty(name)
}

// _objectEnvironment

type _objectEnvironment struct {
	runtime *_runtime
    outer _environment
    Object *_object
	ProvideThis bool
}

func (runtime *_runtime) newObjectEnvironment(object *_object, outer _environment) *_objectEnvironment {
	if object == nil {
		object = runtime.newBaseObject()
	}
    return &_objectEnvironment{
		runtime: runtime,
		outer: outer,
        Object: object,
    }
}

func (self *_objectEnvironment) HasBinding(name string) bool {
	return self.Object.hasProperty(name)
}

func (self *_objectEnvironment) CreateMutableBinding(name string, configure bool) {
	if self.Object.hasProperty(name) {
		panic(hereBeDragons())
	}
	self.Object.stash.put(name, UndefinedValue())
}

func (self *_objectEnvironment) SetMutableBinding(name string, value Value, strict bool) {
	self.Object.set(name, value, strict)
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

func (runtime *_runtime) newDeclarativeEnvironment(outer _environment) *_objectEnvironment {
	// Just an _objectEnvironment (for now)
	return &_objectEnvironment{
		runtime: runtime,
		outer: outer,
		Object: runtime.newBaseObject(),
	}
}
type _declarativeProperty struct {
	value Value
	deletable bool
}

type _declarativeEnvironment struct {
	runtime *_runtime
    outer _environment
	stash map[string]*_declarativeProperty
}
