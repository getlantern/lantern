package otto

import (
	"fmt"
)

func (self *_runtime) evaluateBody(list []_node) Value {
	value := Value{}
	for _, child := range list {
		result := self.evaluate(child)
		if !result.isEmpty() {
			// We have GetValue here to (for example) trigger a
			// ReferenceError (of the not defined variety)
			// Not sure if this is the best way to error out early
			// for such errors or if there is a better way
			value = self.GetValue(result)
		}
	}
	return value
}

func (self *_runtime) evaluate(node _node) Value {
	defer func() {
		// This defer is lame (unecessary overhead)
		// It would be better to mark the errors at the source
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case _error:
				if caught.Line == -1 {
					caught.Line = node.position()
				}
				panic(caught) // Panic the modified _error
			}
			panic(caught)
		}
	}()

    switch node := node.(type) {

    case *_variableDeclarationListNode:
		return self.evaluateVariableDeclarationList(node)

    case *_variableDeclarationNode:
		return self.evaluateVariableDeclaration(node)

    case *_programNode:
		self.declare("function", node.FunctionList)
		self.declare("variable", node.VariableList)
		return self.evaluateBody(node.Body)

    case *_blockNode:
		return self.evaluateBody(node.Body)

    case *_valueNode:
		return self.evaluateValue(node)

    case *_identifierNode:
		return self.evaluateIdentifier(node)

	case *_functionNode:
		return self.evaluateFunction(node)

	case *_binaryOperationNode:
		return self.evaluateBinaryOperation(node)

	case *_assignmentNode:
		return self.evaluateAssignment(node)

	case *_unaryOperationNode:
		return self.evaluateUnaryOperation(node)

	case *_comparisonNode:
		return self.evaluateComparison(node)

	case *_returnNode:
		return self.evaluateReturn(node)

	case *_ifNode:
		return self.evaluateIf(node)

	case *_doWhileNode:
		return self.evaluateDoWhile(node)

	case *_whileNode:
		return self.evaluateWhile(node)

	case *_callNode:
		return self.evaluateCall(node)

	case *_continueNode:
		self.Continue(node.Target)

	case *_switchNode:
		return self.evaluateSwitch(node)

	case *_forNode:
		return self.evaluateFor(node)

	case *_forInNode:
		return self.evaluateForIn(node)

	case *_breakNode:
		self.Break(node.Target)

	case *_throwNode:
		return self.evaluateThrow(node)

	case *_emptyNode:
		return emptyValue()

	case *_tryCatchNode:
		return self.evaluateTryCatch(node)

	case *_dotMemberNode:
		return self.evaluateDotMember(node)

	case *_bracketMemberNode:
		return self.evaluateBracketMember(node)

	case *_objectNode:
		return self.evaluateObject(node)

	case *_regExpNode:
		return self.evaluateRegExp(node)

	case *_arrayNode:
		return self.evaluateArray(node)

	case *_newNode:
		return self.evaluateNew(node)

	case *_conditionalNode:
		return self.evaluateConditional(node)

	case *_thisNode:
		return toValue(self._executionContext(0).this)

	case *_commaNode:
		return self.evaluateComma(node)

	case *_withNode:
		return self.evaluateWith(node)

    }

	panic(fmt.Sprintf("evaluate: Here be dragons: %T %v", node, node))
}
