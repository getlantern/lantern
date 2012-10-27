package otto

type _reference interface {
	GetBase() *_object
	GetValue() Value
	PutValue(Value) bool
	Name() string
	Strict() bool
	Delete()
}

type _reference_ struct {
    name string
	strict bool
}

func (self _reference_) GetBase() *_object {
	return nil
}

func (self _reference_) Name() string {
	return self.name
}

func (self _reference_) Strict() bool {
	return self.strict
}

func (self _reference_) Delete() {
	// TODO Does nothing, for now?
}

type _argumentReference struct {
	_reference_
    Base *_object
}

func newArgumentReference(base *_object, name string, strict bool) *_argumentReference {
	if base == nil {
		panic(hereBeDragons())
	}
	return &_argumentReference{
		Base: base,
		_reference_: _reference_{
			name: name,
			strict: strict,
		},
	}
}

func (self *_argumentReference) GetBase() *_object {
	return self.Base
}

func (self *_argumentReference) GetValue() Value {
	return self.Base.get(self.name)
}

func (self *_argumentReference) PutValue(value Value) bool {
	self.Base.set(self.name, value, self._reference_.strict)
	return true
}

type _objectReference struct {
	_reference_
    Base *_object
	node _node
}

func newObjectReference(base *_object, name string, strict bool, node _node) *_objectReference {
	return &_objectReference{
		Base: base,
		_reference_: _reference_{
			name: name,
			strict: strict,
		},
		node: node,
	}
}

func (self *_objectReference) GetBase() *_object {
	return self.Base
}

func (self *_objectReference) GetValue() Value {
	if self.Base == nil {
		panic(newReferenceError("notDefined", self.name, self.node))
	}
	return self.Base.get(self.name)
}

func (self *_objectReference) PutValue(value Value) bool {
	if self.Base == nil {
		return false
	}
	self.Base.set(self.name, value, self.Strict())
	return true
}

func (self *_objectReference) Delete() {
	if self.Base == nil {
		return
	}
	self.Base.delete(self.name, self.Strict())
}

type _primitiveReference struct {
	_reference_
    Base Value
	toObject func(Value) *_object
	baseObject *_object
}

func newPrimitiveReference(base Value, toObject func(Value) *_object, name string, strict bool) *_primitiveReference {
	return &_primitiveReference{
		Base: base,
		toObject: toObject,
		_reference_: _reference_{
			name: name,
			strict: strict,
		},
	}
}

func (self *_primitiveReference) baseAsObject() *_object {
	if self.baseObject == nil {
		self.baseObject = self.toObject(self.Base)
	}
	return self.baseObject
}

func (self *_primitiveReference) GetValue() Value {
	return self.baseAsObject().get(self.name)
}

func (self *_primitiveReference) PutValue(value Value) bool {
	self.baseAsObject().set(self.name, value, self.Strict())
	return true
}

