package otto

// property

type _propertyMode int

const (
	propertyMode_write     _propertyMode = 0100
	propertyMode_enumerate               = 0010
	propertyMode_configure               = 0001
)

type _propertyGetSet [2]*_object

type _property struct {
	value interface{}
	mode  _propertyMode
}

func (self _property) writeable() bool {
	return self.mode & 0700 == 0100
}

func (self _property) enumerable() bool {
	return self.mode & 0070 == 0010
}

func (self _property) configureable() bool {
	return self.mode & 0007 == 0001
}

func (self _property) copy() *_property {
	property := self
	return &property
}

func (self _property) isAccessorDescriptor() bool {
	setGet, test := self.value.(_propertyGetSet)
	return test && setGet[0] != nil || setGet[1] != nil
}

func (self _property) isDataDescriptor() bool {
	value, test := self.value.(Value)
	return self.mode & 0700 != 0200 || (test && !value.isEmpty())
}

func (self _property) isGenericDescriptor() bool {
	return !(self.isDataDescriptor() || self.isAccessorDescriptor())
}

func (self _property) isEmpty() bool {
	return self.mode == 0222 && self.isGenericDescriptor()
}

// _enumerableValue, _enumerableTrue, _enumerableFalse?
// .enumerableValue()
