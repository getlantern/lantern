package otto

func (runtime *_runtime) newArgumentsObject(argumentList []Value) *_object {
	self := runtime.newClassObject("Arguments")
	self.Prototype = runtime.Global.ObjectPrototype

	for index, value := range argumentList {
		// TODO Write test for runtime.GetValue(value)
		// The problem here is possible reference nesting, is this the right place to GetValue?
		self.WriteValue(arrayIndexToString(uint(index)), runtime.GetValue(value), false)
	}
	self.DefineOwnProperty("length", _property{Value: toValue(len(argumentList)), Mode: propertyModeWrite | propertyModeConfigure}.toDefineProperty(), false)

	return self
}

