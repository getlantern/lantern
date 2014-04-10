package otto

import (
	"fmt"
	"runtime"

	"github.com/robertkrimen/otto/ast"
	"github.com/robertkrimen/otto/token"
)

func (self *_runtime) evaluateBody(body []ast.Statement) Value {
	bodyValue := Value{}
	for _, node := range body {
		value := self.evaluate(node)
		if value.isResult() {
			return value
		}
		if !value.isEmpty() {
			// We have GetValue here to (for example) trigger a
			// ReferenceError (of the not defined variety)
			// Not sure if this is the best way to error out early
			// for such errors or if there is a better way
			bodyValue = self.GetValue(value)
		}
	}
	return bodyValue
}

func (self *_runtime) evaluate(node ast.Node) Value {
	defer func() {
		// This defer is lame (unecessary overhead)
		// It would be better to mark the errors at the source
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case _error:
				if caught.Line == -1 {
					//caught.Line = ast.position()
				}
				panic(caught) // Panic the modified _error
			}
			panic(caught)
		}
	}()

	// Allow interpreter interruption
	// If the Interrupt channel is nil, then
	// we avoid runtime.Gosched() overhead (if any)
	if self.Otto.Interrupt != nil {
		runtime.Gosched()
		select {
		case value := <-self.Otto.Interrupt:
			value()
		default:
		}
	}

	switch node := node.(type) {

	case *ast.VariableExpression:
		return self.evaluateVariableExpression(node)

	case *ast.VarStatement:
		// Variables are already defined, this is initialization only
		for _, variable := range node.List {
			self.evaluateVariableExpression(variable.(*ast.VariableExpression))
		}
		return Value{}

	case *ast.Program:
		self.functionDeclaration(node.FunctionList)
		self.variableDeclaration(node.VariableList)
		return self.evaluateBody(node.Body)

	case *ast.ExpressionStatement:
		return self.evaluate(node.Expression)

	case *ast.BlockStatement:
		return self.evaluateBlockStatement(node)

	case *ast.NullLiteral:
		return NullValue()

	case *ast.BooleanLiteral:
		return toValue_bool(node.Value)

	case *ast.StringLiteral:
		return toValue_string(node.Value)

	case *ast.NumberLiteral:
		return toValue_float64(stringToFloat(node.Literal))

	case *ast.ObjectLiteral:
		return self.evaluateObject(node)

	case *ast.RegExpLiteral:
		return self.evaluateRegExpLiteral(node)

	case *ast.ArrayLiteral:
		return self.evaluateArray(node)

	case *ast.Identifier:
		return self.evaluateIdentifier(node)

	case *ast.LabelledStatement:
		self.labels = append(self.labels, node.Label.Name)
		defer func() {
			if len(self.labels) > 0 {
				self.labels = self.labels[:len(self.labels)-1] // Pop the label
			} else {
				self.labels = nil
			}
		}()
		return self.evaluate(node.Statement)

	case *ast.BinaryExpression:
		if node.Comparison {
			return self.evaluateComparison(node)
		} else {
			return self.evaluateBinaryExpression(node)
		}

	case *ast.AssignExpression:
		return self.evaluateAssignExpression(node)

	case *ast.UnaryExpression:
		return self.evaluateUnaryExpression(node)

	case *ast.ReturnStatement:
		return self.evaluateReturnStatement(node)

	case *ast.IfStatement:
		return self.evaluateIfStatement(node)

	case *ast.DoWhileStatement:
		return self.evaluateDoWhileStatement(node)

	case *ast.WhileStatement:
		return self.evaluateWhileStatement(node)

	case *ast.CallExpression:
		return self.evaluateCall(node, nil)

	case *ast.BranchStatement:
		target := ""
		if node.Label != nil {
			target = node.Label.Name
		}
		switch node.Token {
		case token.BREAK:
			return toValue(newBreakResult(target))
		case token.CONTINUE:
			return toValue(newContinueResult(target))
		}

	case *ast.SwitchStatement:
		return self.evaluateSwitchStatement(node)

	case *ast.ForStatement:
		return self.evaluateForStatement(node)

	case *ast.ForInStatement:
		return self.evaluateForInStatement(node)

	case *ast.ThrowStatement:
		return self.evaluateThrowStatement(node)

	case *ast.EmptyStatement:
		return Value{}

	case *ast.TryStatement:
		return self.evaluateTryStatement(node)

	case *ast.DotExpression:
		return self.evaluateDotExpression(node)

	case *ast.BracketExpression:
		return self.evaluateBracketExpression(node)

	case *ast.NewExpression:
		return self.evaluateNew(node)

	case *ast.ConditionalExpression:
		return self.evaluateConditionalExpression(node)

	case *ast.ThisExpression:
		return toValue_object(self._executionContext(0).this)

	case *ast.SequenceExpression:
		return self.evaluateSequenceExpression(node)

	case *ast.WithStatement:
		return self.evaluateWithStatement(node)

	case *ast.FunctionExpression:
		return self.evaluateFunction(node)

	}

	panic(fmt.Sprintf("evaluate: Here be dragons: %T %v", node, node))
}
