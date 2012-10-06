package otto

type _executionContext struct {
    LexicalEnvironment _environment
    VariableEnvironment _environment
    this *_object
}

func newExecutionContext(lexical _environment, variable _environment, this *_object) *_executionContext {
    return &_executionContext{
        LexicalEnvironment: lexical,
        VariableEnvironment: variable,
        this: this,
    }
}

func (self *_executionContext) GetValue(name string) Value {
	strict := false
    return self.LexicalEnvironment.GetValue(name, strict)
}

func (self *_executionContext) SetValue(name string, value Value, throw bool) {
    self.LexicalEnvironment.SetValue(name, value, throw)
}

func (self *_executionContext) newLexicalEnvironment(object *_object) (_environment, *_objectEnvironment) {
	previousLexical := self.LexicalEnvironment
	newLexical := self.LexicalEnvironment.newObjectEnvironment(object)
	self.LexicalEnvironment = newLexical
	return previousLexical, newLexical
}

func (self *_executionContext) newDeclarativeEnvironment() _environment {
	previousLexical := self.LexicalEnvironment
	self.LexicalEnvironment = self.LexicalEnvironment.newDeclarativeEnvironment()
	return previousLexical
}
