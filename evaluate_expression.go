package otto

import (
	"fmt"
	"math"
	"strings"

	"github.com/robertkrimen/otto/ast"
	"github.com/robertkrimen/otto/token"
)

func (self *_runtime) evaluateConditionalExpression(node *ast.ConditionalExpression) Value {
	test := self.evaluate(node.Test)
	testValue := self.GetValue(test)
	if toBoolean(testValue) {
		return self.evaluate(node.Consequent)
	}
	return self.evaluate(node.Alternate)
}

func (self *_runtime) evaluateVariableExpression(node *ast.VariableExpression) Value {
	if node.Initializer != nil {
		// FIXME If reference is nil
		left := getIdentifierReference(self.LexicalEnvironment(), node.Name, false, node)
		right := self.evaluate(node.Initializer)
		rightValue := self.GetValue(right)

		self.PutValue(left, rightValue)
	}
	return toValue_string(node.Name)
}

func (self *_runtime) evaluateNew(node *ast.NewExpression) Value {
	callee := self.evaluate(node.Callee)
	calleeValue := self.GetValue(callee)
	argumentList := []Value{}
	for _, argumentNode := range node.ArgumentList {
		argumentList = append(argumentList, self.GetValue(self.evaluate(argumentNode)))
	}
	this := UndefinedValue()
	if !calleeValue.IsFunction() {
		panic(newTypeError("%v is not a function", calleeValue))
	}
	return calleeValue._object().Construct(this, argumentList)
}

func (self *_runtime) evaluateArray(node *ast.ArrayLiteral) Value {

	valueArray := []Value{}

	for _, node := range node.Value {
		if node == nil {
			valueArray = append(valueArray, Value{})
		} else {
			valueArray = append(valueArray, self.GetValue(self.evaluate(node)))
		}
	}

	result := self.newArrayOf(valueArray)

	return toValue_object(result)
}

func (self *_runtime) evaluateObject(node *ast.ObjectLiteral) Value {

	result := self.newObject()

	for _, property := range node.Value {
		switch property.Kind {
		case "value":
			result.defineProperty(property.Key, self.GetValue(self.evaluate(property.Value)), 0111, false)
		case "get":
			getter := self.newNodeFunction(property.Value.(*ast.FunctionExpression), self.LexicalEnvironment())
			descriptor := _property{}
			descriptor.mode = 0211
			descriptor.value = _propertyGetSet{getter, nil}
			result.defineOwnProperty(property.Key, descriptor, false)
		case "set":
			setter := self.newNodeFunction(property.Value.(*ast.FunctionExpression), self.LexicalEnvironment())
			descriptor := _property{}
			descriptor.mode = 0211
			descriptor.value = _propertyGetSet{nil, setter}
			result.defineOwnProperty(property.Key, descriptor, false)
		default:
			panic(fmt.Errorf("evaluateObject: invalid property.Kind: %v", property.Kind))
		}
	}

	return toValue_object(result)
}

func (self *_runtime) evaluateRegExpLiteral(node *ast.RegExpLiteral) Value {
	return toValue_object(self._newRegExp(node.Pattern, node.Flags))
}

func (self *_runtime) evaluateUnaryExpression(node *ast.UnaryExpression) Value {

	target := self.evaluate(node.Operand)
	switch node.Operator {
	case token.TYPEOF, token.DELETE:
		if target._valueType == valueReference && target.reference().IsUnresolvable() {
			if node.Operator == token.TYPEOF {
				return toValue_string("undefined")
			}
			return TrueValue()
		}
	}

	targetValue := self.GetValue(target)

	switch node.Operator {
	case token.NOT:
		if targetValue.toBoolean() {
			return FalseValue()
		}
		return TrueValue()
	case token.BITWISE_NOT:
		integerValue := toInt32(targetValue)
		return toValue_int32(^integerValue)
	case token.PLUS:
		return toValue_float64(targetValue.toFloat())
	case token.MINUS:
		value := targetValue.toFloat()
		// TODO Test this
		sign := float64(-1)
		if math.Signbit(value) {
			sign = 1
		}
		return toValue_float64(math.Copysign(value, sign))
	case token.INCREMENT:
		if node.Postfix {
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
		if node.Postfix {
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
		return UndefinedValue()
	case token.DELETE:
		reference := target.reference()
		if reference == nil {
			return TrueValue()
		}
		return toValue_bool(target.reference().Delete())
	case token.TYPEOF:
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
			if targetValue._object().functionValue().call != nil {
				return toValue_string("function")
			}
			return toValue_string("object")
		default:
			// ?
		}
	}

	panic(hereBeDragons())
}

func (self *_runtime) evaluateMultiply(left float64, right float64) Value {
	// TODO 11.5.1
	return UndefinedValue()
}

func (self *_runtime) evaluateDivide(left float64, right float64) Value {
	if math.IsNaN(left) || math.IsNaN(right) {
		return NaNValue()
	}
	if math.IsInf(left, 0) && math.IsInf(right, 0) {
		return NaNValue()
	}
	if left == 0 && right == 0 {
		return NaNValue()
	}
	if math.IsInf(left, 0) {
		if math.Signbit(left) == math.Signbit(right) {
			return positiveInfinityValue()
		} else {
			return negativeInfinityValue()
		}
	}
	if math.IsInf(right, 0) {
		if math.Signbit(left) == math.Signbit(right) {
			return positiveZeroValue()
		} else {
			return negativeZeroValue()
		}
	}
	if right == 0 {
		if math.Signbit(left) == math.Signbit(right) {
			return positiveInfinityValue()
		} else {
			return negativeInfinityValue()
		}
	}
	return toValue_float64(left / right)
}

func (self *_runtime) evaluateModulo(left float64, right float64) Value {
	// TODO 11.5.3
	return UndefinedValue()
}

func (self *_runtime) calculateBinaryExpression(operator token.Token, left Value, right Value) Value {

	leftValue := self.GetValue(left)

	switch operator {

	// Additive
	case token.PLUS:
		leftValue = toPrimitive(leftValue)
		rightValue := self.GetValue(right)
		rightValue = toPrimitive(rightValue)

		if leftValue.IsString() || rightValue.IsString() {
			return toValue_string(strings.Join([]string{leftValue.toString(), rightValue.toString()}, ""))
		} else {
			return toValue_float64(leftValue.toFloat() + rightValue.toFloat())
		}
	case token.MINUS:
		rightValue := self.GetValue(right)
		return toValue_float64(leftValue.toFloat() - rightValue.toFloat())

		// Multiplicative
	case token.MULTIPLY:
		rightValue := self.GetValue(right)
		return toValue_float64(leftValue.toFloat() * rightValue.toFloat())
	case token.SLASH:
		rightValue := self.GetValue(right)
		return self.evaluateDivide(leftValue.toFloat(), rightValue.toFloat())
	case token.REMAINDER:
		rightValue := self.GetValue(right)
		return toValue_float64(math.Mod(leftValue.toFloat(), rightValue.toFloat()))

		// Logical
	case token.LOGICAL_AND:
		left := toBoolean(leftValue)
		if !left {
			return FalseValue()
		}
		return toValue_bool(toBoolean(self.GetValue(right)))
	case token.LOGICAL_OR:
		left := toBoolean(leftValue)
		if left {
			return TrueValue()
		}
		return toValue_bool(toBoolean(self.GetValue(right)))

		// Bitwise
	case token.AND:
		rightValue := self.GetValue(right)
		return toValue_int32(toInt32(leftValue) & toInt32(rightValue))
	case token.OR:
		rightValue := self.GetValue(right)
		return toValue_int32(toInt32(leftValue) | toInt32(rightValue))
	case token.EXCLUSIVE_OR:
		rightValue := self.GetValue(right)
		return toValue_int32(toInt32(leftValue) ^ toInt32(rightValue))

		// Shift
		// (Masking of 0x1f is to restrict the shift to a maximum of 31 places)
	case token.SHIFT_LEFT:
		rightValue := self.GetValue(right)
		return toValue_int32(toInt32(leftValue) << (toUint32(rightValue) & 0x1f))
	case token.SHIFT_RIGHT:
		rightValue := self.GetValue(right)
		return toValue_int32(toInt32(leftValue) >> (toUint32(rightValue) & 0x1f))
	case token.UNSIGNED_SHIFT_RIGHT:
		rightValue := self.GetValue(right)
		// Shifting an unsigned integer is a logical shift
		return toValue_uint32(toUint32(leftValue) >> (toUint32(rightValue) & 0x1f))

	case token.INSTANCEOF:
		rightValue := self.GetValue(right)
		if !rightValue.IsObject() {
			panic(newTypeError("Expecting a function in instanceof check, but got: %v", rightValue))
		}
		return toValue_bool(rightValue._object().HasInstance(leftValue))

	case token.IN:
		rightValue := self.GetValue(right)
		if !rightValue.IsObject() {
			panic(newTypeError())
		}
		return toValue_bool(rightValue._object().hasProperty(toString(leftValue)))
	}

	panic(hereBeDragons(operator))
}

func (self *_runtime) evaluateAssignExpression(node *ast.AssignExpression) Value {

	left := self.evaluate(node.Left)
	right := self.evaluate(node.Right)
	rightValue := self.GetValue(right)

	result := rightValue
	if node.Operator != token.ASSIGN {
		result = self.calculateBinaryExpression(node.Operator, left, rightValue)
	}

	self.PutValue(left.reference(), result)

	return result
}

func valueKindDispatchKey(left _valueType, right _valueType) int {
	return (int(left) << 2) + int(right)
}

var equalDispatch map[int](func(Value, Value) bool) = makeEqualDispatch()

func makeEqualDispatch() map[int](func(Value, Value) bool) {
	key := valueKindDispatchKey
	return map[int](func(Value, Value) bool){

		key(valueNumber, valueObject): func(x Value, y Value) bool { return x.toFloat() == y.toFloat() },
		key(valueString, valueObject): func(x Value, y Value) bool { return x.toFloat() == y.toFloat() },
		key(valueObject, valueNumber): func(x Value, y Value) bool { return x.toFloat() == y.toFloat() },
		key(valueObject, valueString): func(x Value, y Value) bool { return x.toFloat() == y.toFloat() },
	}
}

type _lessThanResult int

const (
	lessThanFalse _lessThanResult = iota
	lessThanTrue
	lessThanUndefined
)

func calculateLessThan(left Value, right Value, leftFirst bool) _lessThanResult {

	x := UndefinedValue()
	y := x

	if leftFirst {
		x = toNumberPrimitive(left)
		y = toNumberPrimitive(right)
	} else {
		y = toNumberPrimitive(right)
		x = toNumberPrimitive(left)
	}

	result := false
	if x._valueType != valueString || y._valueType != valueString {
		x, y := x.toFloat(), y.toFloat()
		if math.IsNaN(x) || math.IsNaN(y) {
			return lessThanUndefined
		}
		result = x < y
	} else {
		x, y := x.toString(), y.toString()
		result = x < y
	}

	if result {
		return lessThanTrue
	}

	return lessThanFalse
}

var lessThanTable [4](map[_lessThanResult]bool) = [4](map[_lessThanResult]bool){
	// <
	map[_lessThanResult]bool{
		lessThanFalse:     false,
		lessThanTrue:      true,
		lessThanUndefined: false,
	},

	// >
	map[_lessThanResult]bool{
		lessThanFalse:     false,
		lessThanTrue:      true,
		lessThanUndefined: false,
	},

	// <=
	map[_lessThanResult]bool{
		lessThanFalse:     true,
		lessThanTrue:      false,
		lessThanUndefined: false,
	},

	// >=
	map[_lessThanResult]bool{
		lessThanFalse:     true,
		lessThanTrue:      false,
		lessThanUndefined: false,
	},
}

func (self *_runtime) calculateComparison(comparator token.Token, left Value, right Value) bool {

	// FIXME Use strictEqualityComparison?
	// TODO This might be redundant now (with regards to evaluateComparison)
	x := self.GetValue(left)
	y := self.GetValue(right)

	kindEqualKind := false
	result := true
	negate := false

	switch comparator {
	case token.LESS:
		result = lessThanTable[0][calculateLessThan(x, y, true)]
	case token.GREATER:
		result = lessThanTable[1][calculateLessThan(y, x, false)]
	case token.LESS_OR_EQUAL:
		result = lessThanTable[2][calculateLessThan(y, x, false)]
	case token.GREATER_OR_EQUAL:
		result = lessThanTable[3][calculateLessThan(x, y, true)]
	case token.STRICT_NOT_EQUAL:
		negate = true
		fallthrough
	case token.STRICT_EQUAL:
		if x._valueType != y._valueType {
			result = false
		} else {
			kindEqualKind = true
		}
	case token.NOT_EQUAL:
		negate = true
		fallthrough
	case token.EQUAL:
		if x._valueType == y._valueType {
			kindEqualKind = true
		} else if x._valueType <= valueUndefined && y._valueType <= valueUndefined {
			result = true
		} else if x._valueType <= valueUndefined || y._valueType <= valueUndefined {
			result = false
		} else if x._valueType <= valueString && y._valueType <= valueString {
			result = x.toFloat() == y.toFloat()
		} else if x._valueType == valueBoolean {
			result = self.calculateComparison(token.EQUAL, toValue_float64(x.toFloat()), y)
		} else if y._valueType == valueBoolean {
			result = self.calculateComparison(token.EQUAL, x, toValue_float64(y.toFloat()))
		} else if x._valueType == valueObject {
			result = self.calculateComparison(token.EQUAL, toPrimitive(x), y)
		} else if y._valueType == valueObject {
			result = self.calculateComparison(token.EQUAL, x, toPrimitive(y))
		} else {
			panic(hereBeDragons("Unable to test for equality: %v ==? %v", x, y))
		}
	default:
		panic(fmt.Errorf("Unknown comparator %s", comparator.String()))
	}

	if kindEqualKind {
		switch x._valueType {
		case valueUndefined, valueNull:
			result = true
		case valueNumber:
			x := x.toFloat()
			y := y.toFloat()
			if math.IsNaN(x) || math.IsNaN(y) {
				result = false
			} else {
				result = x == y
			}
		case valueString:
			result = x.toString() == y.toString()
		case valueBoolean:
			result = x.toBoolean() == y.toBoolean()
		case valueObject:
			result = x._object() == y._object()
		default:
			goto ERROR
		}
	}

	if negate {
		result = !result
	}

	return result

ERROR:
	panic(hereBeDragons("%v (%v) %s %v (%v)", x, x._valueType, comparator, y, y._valueType))
}

func (self *_runtime) evaluateComparison(node *ast.BinaryExpression) Value {

	left := self.GetValue(self.evaluate(node.Left))
	right := self.GetValue(self.evaluate(node.Right))

	return toValue_bool(self.calculateComparison(node.Operator, left, right))
}

func (self *_runtime) evaluateBinaryExpression(node *ast.BinaryExpression) Value {

	left := self.evaluate(node.Left)
	leftValue := self.GetValue(left)

	switch node.Operator {
	// Logical
	case token.LOGICAL_AND:
		if !toBoolean(leftValue) {
			return leftValue
		}
		right := self.evaluate(node.Right)
		return self.GetValue(right)
	case token.LOGICAL_OR:
		if toBoolean(leftValue) {
			return leftValue
		}
		right := self.evaluate(node.Right)
		return self.GetValue(right)
	}

	return self.calculateBinaryExpression(node.Operator, leftValue, self.evaluate(node.Right))
}

func (self *_runtime) evaluateCall(node *ast.CallExpression, withArgumentList []interface{}) Value {
	callee := self.evaluate(node.Callee)
	calleeValue := self.GetValue(callee)
	argumentList := []Value{}
	if withArgumentList != nil {
		argumentList = self.toValueArray(withArgumentList...)
	} else {
		for _, argumentNode := range node.ArgumentList {
			argumentList = append(argumentList, self.GetValue(self.evaluate(argumentNode)))
		}
	}
	this := UndefinedValue()
	calleeReference := callee.reference()
	evalHint := false
	if calleeReference != nil {
		if calleeReference.IsPropertyReference() {
			calleeObject := calleeReference.GetBase().(*_object)
			this = toValue_object(calleeObject)
		} else {
			// TODO ImplictThisValue
		}
		if calleeReference.GetName() == "eval" {
			evalHint = true // Possible direct eval
		}
	}
	if !calleeValue.IsFunction() {
		panic(newTypeError("%v is not a function", calleeValue))
	}
	return self.Call(calleeValue._object(), this, argumentList, evalHint)
}

func (self *_runtime) evaluateFunction(node *ast.FunctionExpression) Value {
	return toValue_object(self.newNodeFunction(node, self.LexicalEnvironment()))
}

func (self *_runtime) evaluateDotExpression(node *ast.DotExpression) Value {
	target := self.evaluate(node.Left)
	targetValue := self.GetValue(target)
	// TODO Pass in base value as-is, and defer toObject till later?
	object, err := self.objectCoerce(targetValue)
	if err != nil {
		panic(newTypeError(fmt.Sprintf("Cannot access member '%s' of %s", node.Identifier.Name, err.Error())))
	}
	return toValue(newPropertyReference(object, node.Identifier.Name, false, node))
}

func (self *_runtime) evaluateBracketExpression(node *ast.BracketExpression) Value {
	target := self.evaluate(node.Left)
	targetValue := self.GetValue(target)
	member := self.evaluate(node.Member)
	memberValue := self.GetValue(member)

	// TODO Pass in base value as-is, and defer toObject till later?
	return toValue(newPropertyReference(self.toObject(targetValue), toString(memberValue), false, node))
}

func (self *_runtime) evaluateIdentifier(node *ast.Identifier) Value {
	name := node.Name
	// TODO Should be true or false (strictness) depending on context
	// getIdentifierReference should not return nil, but we check anyway and panic
	// so as not to propagate the nil into something else
	reference := getIdentifierReference(self.LexicalEnvironment(), name, false, node)
	if reference == nil {
		// Should never get here!
		panic(hereBeDragons("referenceError == nil: " + name))
	}
	return toValue(reference)
}

func (self *_runtime) evaluateSequenceExpression(node *ast.SequenceExpression) Value {
	var result Value
	for _, node := range node.Sequence {
		result = self.evaluate(node)
		result = self.GetValue(result)
	}
	return result
}
