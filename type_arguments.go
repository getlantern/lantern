package otto

func (runtime *_runtime) newArgumentsObject(argumentList []Value) *_object {
	self := runtime.newClassObject("Arguments")
	self.prototype = runtime.Global.ObjectPrototype

	for index, value := range argumentList {
		// TODO Write test for runtime.GetValue(value)
		// The problem here is possible reference nesting, is this the right place to GetValue?
		self.set(arrayIndexToString(uint(index)), runtime.GetValue(value), false)
	}
	self.stash.set("length", toValue(len(argumentList)), 0101)

	return self
}
