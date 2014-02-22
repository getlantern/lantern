package otto

func (self *_runtime) evaluateTryCatch(node *_tryCatchNode) Value {
	tryCatchValue, exception := self.tryCatchEvaluate(func() Value {
		return self.evaluate(node.Try)
	})

	if exception && node.Catch != nil {

		lexicalEnvironment := self._executionContext(0).newDeclarativeEnvironment(self)
		defer func() {
			self._executionContext(0).LexicalEnvironment = lexicalEnvironment
		}()
		// TODO If necessary, convert TypeError<runtime> => TypeError
		// That, is, such errors can be thrown despite not being JavaScript "native"
		self.localSet(node.Catch.Identifier, tryCatchValue)

		tryCatchValue, exception = self.tryCatchEvaluate(func() Value {
			return self.evaluate(node.Catch.Body)
		})
	}

	if node.Finally != nil {
		finallyValue := self.evaluate(node.Finally)
		if finallyValue.isResult() {
			return finallyValue
		}
	}

	if exception {
		panic(newException(tryCatchValue))
	}

	return tryCatchValue
}

func (self *_runtime) evaluateVariableDeclarationList(node *_variableDeclarationListNode) Value {
	for _, node := range node.VariableList {
		self.evaluateVariableDeclaration(node)
	}
	return emptyValue()
}

func (self *_runtime) evaluateVariableDeclaration(node *_variableDeclarationNode) Value {
	if node.Operator != "" {
		// FIXME If reference is nil
		left := getIdentifierReference(self.LexicalEnvironment(), node.Identifier, false, node)
		right := self.evaluate(node.Initializer)
		rightValue := self.GetValue(right)

		self.PutValue(left, rightValue)
	}
	return toValue_string(node.Identifier)
}

func (self *_runtime) evaluateThrow(node *_throwNode) Value {
	value := self.GetValue(self.evaluate(node.Argument))
	panic(newException(value))
}

func (self *_runtime) evaluateReturn(node *_returnNode) Value {
	value := UndefinedValue()
	if node.Argument != nil {
		value = self.GetValue(self.evaluate(node.Argument))
	}

	return toValue(newReturnResult(value))
}

func (self *_runtime) evaluateIf(node *_ifNode) Value {
	test := self.evaluate(node.Test)
	testValue := self.GetValue(test)
	if toBoolean(testValue) {
		return self.evaluate(node.Consequent)
	} else if node.Alternate != nil {
		return self.evaluate(node.Alternate)
	}

	return emptyValue()
}

func (self *_runtime) evaluateWith(node *_withNode) Value {
	object := self.evaluate(node.Object)
	objectValue := self.GetValue(object)
	previousLexicalEnvironment, lexicalEnvironment := self._executionContext(0).newLexicalEnvironment(self.toObject(objectValue))
	lexicalEnvironment.ProvideThis = true
	defer func() {
		self._executionContext(0).LexicalEnvironment = previousLexicalEnvironment
	}()

	return self.evaluate(node.Body)
}

func (self *_runtime) evaluateBlock(node *_blockNode) Value {

	body := node.Body
	labelSet := node.labelSet

	blockValue := self.evaluateBody(body)
	if blockValue.evaluateBreak(labelSet) == resultBreak {
		return Value{}
	}
	return blockValue
}

func (self *_runtime) evaluateDoWhile(node *_doWhileNode) Value {

	test := node.Test
	body := node.body
	labelSet := node.labelSet

	doWhileValue := Value{}
resultBreak:
	for {
		for _, node := range body {
			value := self.evaluate(node)
			switch value.evaluateBreakContinue(labelSet) {
			case resultReturn:
				return value
			case resultBreak:
				break resultBreak
			case resultContinue:
				goto resultContinue
			default: // resultNormal
			}
			if !value.isEmpty() {
				doWhileValue = value
			}
		}
	resultContinue:
		if !self.GetValue(self.evaluate(test)).isTrue() {
			// Stahp: do ... while (false)
			break
		}
	}
	return doWhileValue
}

func (self *_runtime) evaluateWhile(node *_whileNode) Value {

	test := node.Test
	body := node.body
	labelSet := node.labelSet

	whileValue := Value{}
resultBreakContinue:
	for {
		if !self.GetValue(self.evaluate(test)).isTrue() {
			// Stahp: while (false) ...
			break
		}
		for _, node := range body {
			value := self.evaluate(node)
			switch value.evaluateBreakContinue(labelSet) {
			case resultReturn:
				return value
			case resultBreak:
				break resultBreakContinue
			case resultContinue:
				continue resultBreakContinue
			default: // resultNormal
			}
			if !value.isEmpty() {
				whileValue = value
			}
		}
	}
	return whileValue
}

func (self *_runtime) evaluateFor(node *_forNode) Value {

	initial := node.Initial
	test := node.Test
	body := node.body
	update := node.Update
	labelSet := node.labelSet

	if initial != nil {
		initialResult := self.evaluate(initial)
		self.GetValue(initialResult) // Side-effect trigger
	}

	forValue := Value{}
resultBreak:
	for {
		if test != nil {
			testResult := self.evaluate(test)
			testResultValue := self.GetValue(testResult)
			if toBoolean(testResultValue) == false {
				break
			}
		}
		for _, node := range body {
			value := self.evaluate(node)
			switch value.evaluateBreakContinue(labelSet) {
			case resultReturn:
				return value
			case resultBreak:
				break resultBreak
			case resultContinue:
				goto resultContinue
			default: // resultNormal
			}
			if !value.isEmpty() {
				forValue = value
			}
		}
	resultContinue:
		if update != nil {
			updateResult := self.evaluate(update)
			self.GetValue(updateResult) // Side-effect trigger
		}
	}
	return forValue
}

func (self *_runtime) evaluateForIn(node *_forInNode) Value {

	source := self.evaluate(node.Source)
	sourceValue := self.GetValue(source)

	switch sourceValue._valueType {
	case valueUndefined, valueNull:
		return emptyValue()
	}

	sourceObject := self.toObject(sourceValue)

	into := node.Into
	body := node.body
	labelSet := node.labelSet

	forInValue := Value{}
	object := sourceObject
	for object != nil {
		enumerateValue := Value{}
		object.enumerate(false, func(name string) bool {
			into := self.evaluate(into)
			// In the case of: for (var abc in def) ...
			if into.reference() == nil {
				identifier := toString(into)
				// TODO Should be true or false (strictness) depending on context
				into = toValue(getIdentifierReference(self.LexicalEnvironment(), identifier, false, node))
			}
			self.PutValue(into.reference(), toValue_string(name))
			for _, node := range body {
				value := self.evaluate(node)
				switch value.evaluateBreakContinue(labelSet) {
				case resultReturn:
					enumerateValue = value
					return false
				case resultBreak:
					object = nil
					return false
				case resultContinue:
					return true
				default: // resultNormal
				}
				if !value.isEmpty() {
					enumerateValue = value
				}
			}
			return true
		})
		if object == nil {
			break
		}
		object = object.prototype
		if !enumerateValue.isEmpty() {
			forInValue = enumerateValue
		}
	}
	return forInValue
}

func (self *_runtime) evaluateSwitch(node *_switchNode) Value {

	discriminantResult := self.evaluate(node.Discriminant)
	target := node.Default

	for index, clause := range node.CaseList {
		test := clause.Test
		if test != nil {
			if self.calculateComparison("===", discriminantResult, self.evaluate(test)) {
				target = index
				break
			}
		}
	}

	switchValue := Value{}
	if target != -1 {
		labelSet := node.labelSet

		for _, clause := range node.CaseList[target:] {
			value := self.evaluateBody(clause.Body)
			switch value.evaluateBreak(labelSet) {
			case resultReturn:
				return value
			case resultBreak:
				return Value{}
			}
			if !value.isEmpty() {
				switchValue = value
			}
		}
	}

	return switchValue
}
