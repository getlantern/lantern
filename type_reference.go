package otto

type _reference interface {
	GetBase() *_object
	CanResolve() bool
	GetValue() Value
	PutValue(Value) bool
	Name() string
	Strict() bool
	Delete() bool
}

// Reference

type _reference_ struct {
	name   string
	strict bool
}

func (self _reference_) Name() string {
	return self.name
}

func (self _reference_) Strict() bool {
	return self.strict
}

// PropertyReference

type _propertyReference struct {
	_reference_
	Base *_object
	node _node
}

func newPropertyReference(base *_object, name string, strict bool, node _node) *_propertyReference {
	return &_propertyReference{
		Base: base,
		_reference_: _reference_{
			name:   name,
			strict: strict,
		},
		node: node,
	}
}

func (self *_propertyReference) GetBase() *_object {
	return self.Base
}

func (self *_propertyReference) CanResolve() bool {
	return self.Base != nil
}

func (self *_propertyReference) GetValue() Value {
	if self.Base == nil {
		panic(newReferenceError("notDefined", self.name, self.node))
	}
	return self.Base.get(self.name)
}

func (self *_propertyReference) PutValue(value Value) bool {
	if self.Base == nil {
		return false
	}
	self.Base.set(self.name, value, self.Strict())
	return true
}

func (self *_propertyReference) Delete() bool {
	if self.Base == nil {
		// ?
		// TODO Throw an error if strict
		return true
	}
	return self.Base.delete(self.name, self.Strict())
}

// ArgumentReference

func newArgumentReference(base *_object, name string, strict bool) *_propertyReference {
	if base == nil {
		panic(hereBeDragons())
	}
	return newPropertyReference(base, name, strict, nil)
}

type _environmentReference struct {
	_reference_
	Base _environment
	node _node
}

func newEnvironmentReference(base _environment, name string, strict bool, node _node) *_environmentReference {
	return &_environmentReference{
		Base: base,
		_reference_: _reference_{
			name:   name,
			strict: strict,
		},
		node: node,
	}
}

func (self *_environmentReference) GetBase() *_object {
	return nil // FIXME
}

func (self *_environmentReference) CanResolve() bool {
	return true // FIXME
}

func (self *_environmentReference) GetValue() Value {
	if self.Base == nil {
		panic(newReferenceError("notDefined", self.name, self.node))
	}
	return self.Base.GetValue(self.name, self.Strict())
}

func (self *_environmentReference) PutValue(value Value) bool {
	if self.Base == nil {
		return false
	}
	self.Base.SetValue(self.name, value, self.Strict())
	return true
}

func (self *_environmentReference) Delete() bool {
	if self.Base == nil {
		// ?
		return false
	}
	return self.Base.DeleteBinding(self.name)
}

// getIdentifierReference

func getIdentifierReference(environment _environment, name string, strict bool, node _node) _reference {
	if environment == nil {
		return newPropertyReference(nil, name, strict, node)
	}
	if environment.HasBinding(name) {
		return environment.newReference(name, strict)
	}
	return getIdentifierReference(environment.Outer(), name, strict, node)
}
