package otto

type _stash interface {
	test(string) bool
	get(string) Value
	property(string) *_property
	enumerate(func(string))

	canPut(string) bool
	put(string, Value)
	set(string, Value, _propertyMode)
	define(string, _defineProperty) bool

	delete(string)

	extensible() bool
	lock()
	unlock()
}

type _objectStash struct {
	_extensible bool
	propertyMap map[string]_property
}

func newObjectStash(extensible bool) *_objectStash {
	return &_objectStash{
		_extensible: extensible,
		propertyMap: make(map[string]_property),
	}
}

func (self *_objectStash) test(name string) bool {
	_, exists := self.propertyMap[name]
	return exists
}

func (self *_objectStash) get(name string) Value {
	property, exists := self.propertyMap[name]

	if !exists {
		return UndefinedValue()
	}

	switch value := property.Value.(type) {
	case Value:
		return value
	case _propertyGetSet:
		if value[0] == nil {
			return UndefinedValue()
		}
		return value[0].CallGet(name)
	}

	panic(hereBeDragons())
}

func (self *_objectStash) property(name string) *_property {
	property, exists := self.propertyMap[name]
	if !exists {
		return nil
	}
	return &property
}

func (self _objectStash) index(name string) (_property, bool) {
	property := self.property(name)
	if property == nil {
		return _property{}, false
	}
	return *property, true
}

func (self *_objectStash) enumerate(each func(string)) {
	for name, property := range self.propertyMap {
		if property.CanEnumerate() {
			each(name)
		}
	}
}

func (self *_objectStash) canPut(name string) bool {
	property, exists := self.propertyMap[name]
	if !exists {
		return self.extensible()
	}
	switch propertyValue := property.Value.(type) {
	case Value:
		return property.CanWrite()
	case _propertyGetSet:
		return propertyValue[1] != nil
	}
	panic(hereBeDragons())
}

func (self *_objectStash) put(name string, value Value) {
	property, exists := self.propertyMap[name]
	if exists {
		switch propertyValue := property.Value.(type) {
		case Value:
			if property.CanWrite() {
				property.Value = value
				self.propertyMap[name] = property
			}
		case _propertyGetSet:
			if propertyValue[1] != nil {
				propertyValue[1].CallSet(name, value)
			}
		}
	} else if self.extensible() {
		self.propertyMap[name] = _property{value, 0111} // Write, Enumerate, Configure
	}
}

func (self *_objectStash) set(name string, value Value, mode _propertyMode) {
	self.propertyMap[name] = _property{value, mode}
}

// FIME This is wrong, and doesn't work like you think
func (self *_objectStash) define(name string, define _defineProperty) bool {
	property, exists := self.index(name)
	if !exists {
		if !self.extensible() {
			return false
		}
		self.propertyMap[name] = _property{
			Value: define.Value,
			Mode:  define.Mode(),
		}
		return true
	}
	if define.isEmpty() {
		return true
	}

	// TODO Per 8.12.9.6 - We should shortcut here (returning true) if
	// the current and new (define) properties are the same

	// TODO Use the other stash methods so we write to special properties properly?

	canConfigure := property.CanConfigure()
	if !canConfigure {
		if define.CanConfigure() {
			return false
		}
		if define.Enumerate != propertyAttributeNotSet && define.CanEnumerate() != property.CanEnumerate() {
			return false
		}
	}
	value, isDataDescriptor := property.Value.(Value)
	getSet, _ := property.Value.(_propertyGetSet)
	if define.IsGenericDescriptor() {
		// GenericDescriptor
	} else if isDataDescriptor != define.IsDataDescriptor() {
		var interface_ interface{}
		if isDataDescriptor {
			property.Mode = property.Mode & ^propertyModeWrite
			property.Value = interface_
		} else {
			property.Mode |= propertyModeWrite
			property.Value = interface_
		}
	} else if isDataDescriptor && define.IsDataDescriptor() {
		if !canConfigure {
			if property.CanWrite() != define.CanWrite() {
				return false
			} else if !sameValue(value, define.Value.(Value)) {
				return false
			}
		}
	} else {
		if !canConfigure {
			defineGetSet, _ := define.Value.(_propertyGetSet)
			if getSet[0] != defineGetSet[0] || getSet[1] != defineGetSet[1] {
				return false
			}
		}
	}
	define.CopyInto(&property)
	self.propertyMap[name] = property
	return true
}

func (self *_objectStash) delete(name string) {
	delete(self.propertyMap, name)
}

func (self _objectStash) extensible() bool {
	return self._extensible
}

func (self *_objectStash) lock() {
	self._extensible = false
}

func (self *_objectStash) unlock() {
	self._extensible = true
}
