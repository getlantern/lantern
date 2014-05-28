package otto

type _reference interface {
	invalid() bool         // IsUnresolvableReference
	getValue() Value       // getValue
	putValue(Value) string // PutValue
	delete() bool
}

// PropertyReference

type _propertyReference struct {
	name   string
	strict bool
	base   *_object
}

func newPropertyReference(base *_object, name string, strict bool) *_propertyReference {
	return &_propertyReference{
		name:   name,
		strict: strict,
		base:   base,
	}
}

func (self *_propertyReference) invalid() bool {
	return self.base == nil
}

func (self *_propertyReference) getValue() Value {
	if self.base == nil {
		panic(newReferenceError("notDefined", self.name))
	}
	return self.base.get(self.name)
}

func (self *_propertyReference) putValue(value Value) string {
	if self.base == nil {
		return self.name
	}
	self.base.put(self.name, value, self.strict)
	return ""
}

func (self *_propertyReference) delete() bool {
	if self.base == nil {
		// TODO Throw an error if strict
		return true
	}
	return self.base.delete(self.name, self.strict)
}

// ArgumentReference

func newArgumentReference(base *_object, name string, strict bool) *_propertyReference {
	if base == nil {
		panic(hereBeDragons())
	}
	return newPropertyReference(base, name, strict)
}

type _stashReference struct {
	name   string
	strict bool
	base   _stash
}

func (self *_stashReference) invalid() bool {
	return false // The base (an environment) will never be nil
}

func (self *_stashReference) getValue() Value {
	if self.base == nil {
		// This should never be reached, but just in case
	}
	return self.base.getBinding(self.name, self.strict)
}

func (self *_stashReference) putValue(value Value) string {
	self.base.setValue(self.name, value, self.strict)
	return ""
}

func (self *_stashReference) delete() bool {
	if self.base == nil {
		// This should never be reached, but just in case
		return false
	}
	return self.base.deleteBinding(self.name)
}

// getIdentifierReference

func getIdentifierReference(stash _stash, name string, strict bool) _reference {
	if stash == nil {
		return newPropertyReference(nil, name, strict)
	}
	if stash.hasBinding(name) {
		return stash.newReference(name, strict)
	}
	return getIdentifierReference(stash.outer(), name, strict)
}
