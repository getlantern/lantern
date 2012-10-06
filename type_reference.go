package otto

type _reference interface {
	GetBase() *_object
	GetValue() Value
	PutValue(Value) bool
	Name() string
	Strict() bool
	Delete()
}

type _referenceBase struct {
    name string
	strict bool
}

func (self _referenceBase) GetBase() *_object {
	return nil
}

func (self _referenceBase) Name() string {
	return self.name
}

func (self _referenceBase) Strict() bool {
	return self.strict
}

func (self _referenceBase) Delete() {
	// TODO Does nothing, for now?
}

type _argumentReference struct {
	_referenceBase
    Base *_object
}

func newArgumentReference(base *_object, name string, strict bool) *_argumentReference {
	if base == nil {
		panic(hereBeDragons())
	}
	return &_argumentReference{
		Base: base,
		_referenceBase: _referenceBase{
			name: name,
			strict: strict,
		},
	}
}

func (self *_argumentReference) GetBase() *_object {
	return self.Base
}

func (self *_argumentReference) GetValue() Value {
	return self.Base.GetValue(self.name)
}

func (self *_argumentReference) PutValue(value Value) bool {
	self.Base.WriteValue(self.name, value, self._referenceBase.strict)
	return true
}

type _objectReference struct {
	_referenceBase
    Base *_object
}

func newObjectReference(base *_object, name string, strict bool) *_objectReference {
	return &_objectReference{
		Base: base,
		_referenceBase: _referenceBase{
			name: name,
			strict: strict,
		},
	}
}

func (self *_objectReference) GetBase() *_object {
	return self.Base
}

func (self *_objectReference) GetValue() Value {
	if self.Base == nil {
		panic(newReferenceError("notDefined", self.name))
	}
	return self.Base.GetValue(self.name)
}

func (self *_objectReference) PutValue(value Value) bool {
	if self.Base == nil {
		return false
	}
	self.Base.WriteValue(self.name, value, self.Strict())
	return true
}

func (self *_objectReference) Delete() {
	if self.Base == nil {
		return
	}
	self.Base.Delete(self.name, self.Strict())
}

type _primitiveReference struct {
	_referenceBase
    Base Value
	toObject func(Value) *_object
	baseObject *_object
}

func newPrimitiveReference(base Value, toObject func(Value) *_object, name string, strict bool) *_primitiveReference {
	return &_primitiveReference{
		Base: base,
		toObject: toObject,
		_referenceBase: _referenceBase{
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
	return self.baseAsObject().GetValue(self.name)
}

func (self *_primitiveReference) PutValue(value Value) bool {
	self.baseAsObject().WriteValue(self.name, value, self.Strict())
	return true
}

