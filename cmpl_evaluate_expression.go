package otto

import (
	"fmt"
	"math"
	"runtime"

	"github.com/robertkrimen/otto/token"
)

func (self *_runtime) cmpl_evaluate_nodeExpression(node _nodeExpression) Value {
	// Allow interpreter interruption
	// If the Interrupt channel is nil, then
	// we avoid runtime.Gosched() overhead (if any)
	// FIXME: Test this
	if self.otto.Interrupt != nil {
		runtime.Gosched()
		select {
		case value := <-self.otto.Interrupt:
			value()
		default:
		}
	}

	switch node := node.(type) {

	case *_nodeArrayLiteral:
		return self.cmpl_evaluate_nodeArrayLiteral(node)

	case *_nodeAssignExpression:
		return self.cmpl_evaluate_nodeAssignExpression(node)

	case *_nodeBinaryExpression:
		if node.comparison {
			return self.cmpl_evaluate_nodeBinaryExpression_comparison(node)
		} else {
			return self.cmpl_evaluate_nodeBinaryExpression(node)
		}

	case *_nodeBracketExpression:
		return self.cmpl_evaluate_nodeBracketExpression(node)

	case *_nodeCallExpression:
		return self.cmpl_evaluate_nodeCallExpression(node, nil)

	case *_nodeConditionalExpression:
		return self.cmpl_evaluate_nodeConditionalExpression(node)

	case *_nodeDotExpression:
		return self.cmpl_evaluate_nodeDotExpression(node)

	case *_nodeFunctionLiteral:
		var local = self.scope.lexical
		if node.name != "" {
			local = self.newDeclarationStash(local)
		}

		value := toValue_object(self.newNodeFunction(node, local))
		if node.name != "" {
			local.createBinding(node.name, false, value)
		}
		return value

	case *_nodeIdentifier:
		name := node.name
		// TODO Should be true or false (strictness) depending on context
		// getIdentifierReference should not return nil, but we check anyway and panic
		// so as not to propagate the nil into something else
		reference := getIdentifierReference(self.scope.lexical, name, false)
		if reference == nil {
			// Should never get here!
			panic(hereBeDragons("referenceError == nil: " + name))
		}
		return toValue(reference)

	case *_nodeLiteral:
		return node.value

	case *_nodeNewExpression:
		return self.cmpl_evaluate_nodeNewExpression(node)

	case *_nodeObjectLiteral:
		return self.cmpl_evaluate_nodeObjectLiteral(node)

	case *_nodeRegExpLiteral:
		return toValue_object(self._newRegExp(node.pattern, node.flags))

	case *_nodeSequenceExpression:
		return self.cmpl_evaluate_nodeSequenceExpression(node)

	case *_nodeThisExpression:
		return toValue_object(self.scope.this)

	case *_nodeUnaryExpression:
		return self.cmpl_evaluate_nodeUnaryExpression(node)

	case *_nodeVariableExpression:
		return self.cmpl_evaluate_nodeVariableExpression(node)
	}

	panic(fmt.Errorf("Here be dragons: evaluate_nodeExpression(%T)", node))
}

func (self *_runtime) cmpl_evaluate_nodeArrayLiteral(node *_nodeArrayLiteral) Value {

	valueArray := []Value{}

	for _, node := range node.value {
		if node == nil {
			valueArray = append(valueArray, Value{})
		} else {
			valueArray = append(valueArray, self.getValue(self.cmpl_evaluate_nodeExpression(node)))
		}
	}

	result := self.newArrayOf(valueArray)

	return toValue_object(result)
}

func (self *_runtime) cmpl_evaluate_nodeAssignExpression(node *_nodeAssignExpression) Value {

	left := self.cmpl_evaluate_nodeExpression(node.left)
	right := self.cmpl_evaluate_nodeExpression(node.right)
	rightValue := self.getValue(right)

	result := rightValue
	if node.operator != token.ASSIGN {
		result = self.calculateBinaryExpression(node.operator, left, rightValue)
	}

	self.PutValue(left.reference(), result)

	return result
}

func (self *_runtime) cmpl_evaluate_nodeBinaryExpression(node *_nodeBinaryExpression) Value {

	left := self.cmpl_evaluate_nodeExpression(node.left)
	leftValue := self.getValue(left)

	switch node.operator {
	// Logical
	case token.LOGICAL_AND:
		if !toBoolean(leftValue) {
			return leftValue
		}
		right := self.cmpl_evaluate_nodeExpression(node.right)
		return self.getValue(right)
	case token.LOGICAL_OR:
		if toBoolean(leftValue) {
			return leftValue
		}
		right := self.cmpl_evaluate_nodeExpression(node.right)
		return self.getValue(right)
	}

	return self.calculateBinaryExpression(node.operator, leftValue, self.cmpl_evaluate_nodeExpression(node.right))
}

func (self *_runtime) cmpl_evaluate_nodeBinaryExpression_comparison(node *_nodeBinaryExpression) Value {

	left := self.getValue(self.cmpl_evaluate_nodeExpression(node.left))
	right := self.getValue(self.cmpl_evaluate_nodeExpression(node.right))

	return toValue_bool(self.calculateComparison(node.operator, left, right))
}

func (self *_runtime) cmpl_evaluate_nodeBracketExpression(node *_nodeBracketExpression) Value {
	target := self.cmpl_evaluate_nodeExpression(node.left)
	targetValue := self.getValue(target)
	member := self.cmpl_evaluate_nodeExpression(node.member)
	memberValue := self.getValue(member)

	// TODO Pass in base value as-is, and defer toObject till later?
	return toValue(newPropertyReference(self.toObject(targetValue), toString(memberValue), false))
}

func (self *_runtime) cmpl_evaluate_nodeCallExpression(node *_nodeCallExpression, withArgumentList []interface{}) Value {
	callee := self.cmpl_evaluate_nodeExpression(node.callee)
	calleeValue := self.getValue(callee)
	argumentList := []Value{}
	if withArgumentList != nil {
		argumentList = self.toValueArray(withArgumentList...)
	} else {
		for _, argumentNode := range node.argumentList {
			argumentList = append(argumentList, self.getValue(self.cmpl_evaluate_nodeExpression(argumentNode)))
		}
	}
	this := UndefinedValue()
	calleeReference := callee.reference()
	eval := false // Whether this call is a (candidate for) direct call to eval
	if calleeReference != nil {
		switch reference := calleeReference.(type) {
		case *_propertyReference:
			calleeObject := reference.base
			this = toValue_object(calleeObject)
			eval = reference.name == "eval" // Possible direct eval
		case *_stashReference:
			// TODO ImplicitThisValue
			eval = reference.name == "eval" // Possible direct eval
		default:
			panic(newTypeError("Here be dragons"))
		}
	}
	if !calleeValue.IsFunction() {
		panic(newTypeError("%v is not a function", calleeValue))
	}
	return calleeValue._object().call(this, argumentList, eval)
}

func (self *_runtime) cmpl_evaluate_nodeConditionalExpression(node *_nodeConditionalExpression) Value {
	test := self.cmpl_evaluate_nodeExpression(node.test)
	testValue := self.getValue(test)
	if toBoolean(testValue) {
		return self.cmpl_evaluate_nodeExpression(node.consequent)
	}
	return self.cmpl_evaluate_nodeExpression(node.alternate)
}

func (self *_runtime) cmpl_evaluate_nodeDotExpression(node *_nodeDotExpression) Value {
	target := self.cmpl_evaluate_nodeExpression(node.left)
	targetValue := self.getValue(target)
	// TODO Pass in base value as-is, and defer toObject till later?
	object, err := self.objectCoerce(targetValue)
	if err != nil {
		panic(newTypeError(fmt.Sprintf("Cannot access member '%s' of %s", node.identifier, err.Error())))
	}
	return toValue(newPropertyReference(object, node.identifier, false))
}

func (self *_runtime) cmpl_evaluate_nodeNewExpression(node *_nodeNewExpression) Value {
	callee := self.cmpl_evaluate_nodeExpression(node.callee)
	calleeValue := self.getValue(callee)
	argumentList := []Value{}
	for _, argumentNode := range node.argumentList {
		argumentList = append(argumentList, self.getValue(self.cmpl_evaluate_nodeExpression(argumentNode)))
	}
	if !calleeValue.IsFunction() {
		panic(newTypeError("%v is not a function", calleeValue))
	}
	return calleeValue._object().construct(argumentList)
}

func (self *_runtime) cmpl_evaluate_nodeObjectLiteral(node *_nodeObjectLiteral) Value {

	result := self.newObject()

	for _, property := range node.value {
		switch property.kind {
		case "value":
			result.defineProperty(property.key, self.getValue(self.cmpl_evaluate_nodeExpression(property.value)), 0111, false)
		case "get":
			getter := self.newNodeFunction(property.value.(*_nodeFunctionLiteral), self.scope.lexical)
			descriptor := _property{}
			descriptor.mode = 0211
			descriptor.value = _propertyGetSet{getter, nil}
			result.defineOwnProperty(property.key, descriptor, false)
		case "set":
			setter := self.newNodeFunction(property.value.(*_nodeFunctionLiteral), self.scope.lexical)
			descriptor := _property{}
			descriptor.mode = 0211
			descriptor.value = _propertyGetSet{nil, setter}
			result.defineOwnProperty(property.key, descriptor, false)
		default:
			panic(fmt.Errorf("Here be dragons: evaluate_nodeObjectLiteral: invalid property.Kind: %v", property.kind))
		}
	}

	return toValue_object(result)
}

func (self *_runtime) cmpl_evaluate_nodeSequenceExpression(node *_nodeSequenceExpression) Value {
	var result Value
	for _, node := range node.sequence {
		result = self.cmpl_evaluate_nodeExpression(node)
		result = self.getValue(result)
	}
	return result
}

func (self *_runtime) cmpl_evaluate_nodeUnaryExpression(node *_nodeUnaryExpression) Value {

	target := self.cmpl_evaluate_nodeExpression(node.operand)
	switch node.operator {
	case token.TYPEOF, token.DELETE:
		if target._valueType == valueReference && target.reference().invalid() {
			if node.operator == token.TYPEOF {
				return toValue_string("undefined")
			}
			return TrueValue()
		}
	}

	switch node.operator {
	case token.NOT:
		targetValue := self.getValue(target)
		if targetValue.toBoolean() {
			return FalseValue()
		}
		return TrueValue()
	case token.BITWISE_NOT:
		targetValue := self.getValue(target)
		integerValue := toInt32(targetValue)
		return toValue_int32(^integerValue)
	case token.PLUS:
		targetValue := self.getValue(target)
		return toValue_float64(targetValue.toFloat())
	case token.MINUS:
		targetValue := self.getValue(target)
		value := targetValue.toFloat()
		// TODO Test this
		sign := float64(-1)
		if math.Signbit(value) {
			sign = 1
		}
		return toValue_float64(math.Copysign(value, sign))
	case token.INCREMENT:
		targetValue := self.getValue(target)
		if node.postfix {
			// Postfix++
			oldValue := targetValue.toFloat()
			newValue := toValue_float64(+1 + oldValue)
			self.PutValue(target.reference(), newValue)
			return toValue_float64(oldValue)
		} else {
			// ++Prefix
			newValue := toValue_float64(+1 + targetValue.toFloat())
			self.PutValue(target.reference(), newValue)
			return newValue
		}
	case token.DECREMENT:
		targetValue := self.getValue(target)
		if node.postfix {
			// Postfix--
			oldValue := targetValue.toFloat()
			newValue := toValue_float64(-1 + oldValue)
			self.PutValue(target.reference(), newValue)
			return toValue_float64(oldValue)
		} else {
			// --Prefix
			newValue := toValue_float64(-1 + targetValue.toFloat())
			self.PutValue(target.reference(), newValue)
			return newValue
		}
	case token.VOID:
		self.getValue(target) // FIXME Side effect?
		return UndefinedValue()
	case token.DELETE:
		reference := target.reference()
		if reference == nil {
			return TrueValue()
		}
		return toValue_bool(target.reference().delete())
	case token.TYPEOF:
		targetValue := self.getValue(target)
		switch targetValue._valueType {
		case valueUndefined:
			return toValue_string("undefined")
		case valueNull:
			return toValue_string("object")
		case valueBoolean:
			return toValue_string("boolean")
		case valueNumber:
			return toValue_string("number")
		case valueString:
			return toValue_string("string")
		case valueObject:
			if targetValue._object().isCall() {
				return toValue_string("function")
			}
			return toValue_string("object")
		default:
			// FIXME ?
		}
	}

	panic(hereBeDragons())
}

func (self *_runtime) cmpl_evaluate_nodeVariableExpression(node *_nodeVariableExpression) Value {
	if node.initializer != nil {
		// FIXME If reference is nil
		left := getIdentifierReference(self.scope.lexical, node.name, false)
		right := self.cmpl_evaluate_nodeExpression(node.initializer)
		rightValue := self.getValue(right)

		self.PutValue(left, rightValue)
	}
	return toValue_string(node.name)
}
