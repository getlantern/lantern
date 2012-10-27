package otto

type _stash interface {
	test(string) bool
	get(string) Value
	property(string) *_property
	index(string) (_property, bool)
	enumerate(func(string))

	canPut(string) bool
	put(string, Value)
	set(string, Value, _propertyMode)
	defineProperty(string, interface{}, _propertyMode)

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

	switch value := property.value.(type) {
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
		if property.enumerable() {
			each(name)
		}
	}
}

func (self *_objectStash) canPut(name string) bool {
	property, exists := self.propertyMap[name]
	if !exists {
		return self.extensible()
	}
	switch propertyValue := property.value.(type) {
	case Value:
		return property.writable()
	case _propertyGetSet:
		return propertyValue[1] != nil
	}
	panic(hereBeDragons())
}

func (self *_objectStash) put(name string, value Value) {
	property, exists := self.propertyMap[name]
	if exists {
		switch propertyValue := property.value.(type) {
		case Value:
			if property.writable() {
				property.value = value
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

func (self *_objectStash) defineProperty(name string, value interface{}, mode _propertyMode) {
	// TODO Sanity check value?
	self.propertyMap[name] = _property{value, mode}
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
