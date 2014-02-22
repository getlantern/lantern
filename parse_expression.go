package otto

import (
	"regexp"
)

func (self *_parser) ParsePrimaryExpression() _node {
	token := self.Peek()
	switch token.Kind {
	case "identifier":
		return self.ConsumeIdentifier()
	case "string":
		return self.ConsumeString()
	case "boolean":
		return self.ConsumeBoolean()
	case "number":
		return self.ConsumeNumber()
	case "null":
		return self.ConsumeNull()
	case "function":
		return self.ParseFunction(false)
	case "this":
		self.Next()
		node := newThisNode()
		self.markNode(node)
		return node
	case "{":
		return self.ParseObjectLiteral()
	case "[":
		return self.ParseArrayLiteral()
	case "(":
		self.Expect("(")
		result := self.ParseExpression()
		self.Expect(")")
		return result
	case "/", "/=": // Here, "/" & "/=" actually indicate
		// the beginning of a regular expression
		return self.ParseRegExpLiteral(token)
	}

	panic(self.Unexpected(token))
}

func (self *_parser) ParseObjectPropertyKey() string {
	if self.Match("identifier") {
		return self.ConsumeIdentifier().Value
	} else if self.Match("number") {
		return toString(self.ConsumeNumber().Value)
	} else if self.Match("string") {
		return toString(self.ConsumeString().Value)
	}
	token := self.Next()
	if !isIdentifierName(token) {
		panic(self.Unexpected(token))
	}
	return token.Text
}

func (self *_parser) ParseObjectProperty() *_objectPropertyNode {

	key := self.ParseObjectPropertyKey()
	self.Expect(":")
	value := self.ParseAssignmentExpression()

	node := newObjectPropertyNode(key, value)
	self.markNode(node)
	return node
}

func (self *_parser) ParseRegExpLiteral(token _token) *_regExpNode {

	pattern := self.ScanRegularExpression().Text

	flags := ""
	if self.Match("identifier") { // gim
		flags = self.Consume()
	}

	{
		// Test during parsing that this is a valid regular expression
		// Sorry, (?=) and (?!) are invalid (for now)
		pattern := transformRegExp(pattern)
		_, err := regexp.Compile(pattern)
		if err != nil {
			panic(token.newSyntaxError("Invalid regular expression: %s", err.Error()[22:])) // Skip redundant "parse regexp error"
		}
	}

	node := newRegExpNode(pattern, flags)
	self.markNode(node)
	return node
}

func (self *_parser) ParseObjectLiteral() *_objectNode {

	node := newObjectNode()
	self.markNode(node)

	self.Expect("{")
	for !self.Match("}") {
		property := self.ParseObjectProperty()
		node.AddProperty(property)

		if self.Accept(",") {
			continue
		}
	}
	self.Expect("}")

	return node
}

func (self *_parser) ParseArrayValue() _node {
	return self.ParseAssignmentExpression()
}

func (self *_parser) ParseArrayLiteral() *_arrayNode {

	self.Expect("[")
	nodeList := []_node{}
	for !self.Match("]") {
		if self.Accept(",") {
			nodeList = append(nodeList, newEmptyNode())
			continue
		}
		nodeList = append(nodeList, self.ParseArrayValue())
		if !self.Match("]") {
			self.Expect(",")
		}
	}
	self.Expect("]")

	node := newArrayNode(nodeList)
	self.markNode(node)
	return node
}

func (self *_parser) ParseArgumentList() (argumentList []_node) {
	self.Expect("(")
	if !self.Match(")") {
		argumentList = make([]_node, 0)
		for {
			argumentList = append(argumentList, self.ParseAssignmentExpression())
			if !self.Accept(",") {
				break
			}
		}
	}
	self.Expect(")")
	return argumentList
}

func (self *_parser) ParseCallExpression(left _node) _node {
	left = newCallNode(left)
	self.markNode(left)
	left.(*_callNode).ArgumentList = self.ParseArgumentList()
	return left
}

func (self *_parser) ParseDotMember(left _node) _node {
	self.Expect(".")
	token := self.Next()
	member := token.Text
	if !isIdentifierName(token) {
		panic(token.newSyntaxError("Unexpected token %s", token.Kind))
	}
	node := newDotMemberNode(left, member)
	self.markNode(node)
	return node
}

func (self *_parser) ParseBracketMember(left _node) _node {
	self.Expect("[")
	member := self.ParseExpression()
	self.Expect("]")
	node := newBracketMemberNode(left, member)
	self.markNode(node)
	return node
}

func (self *_parser) ParseNewExpression() _node {
	self.Expect("new")
	node := newNewNode(self.ParseLeftHandSideExpression())
	self.markNode(node)
	if self.Match("(") {
		node.ArgumentList = self.ParseArgumentList()
	}
	return node
}

func (self *_parser) ParseLeftHandSideExpression() _node {

	var left _node
	if self.Match("new") {
		left = self.ParseNewExpression()
	} else {
		left = self.ParsePrimaryExpression()
	}

	for {
		if self.Match(".") {
			left = self.ParseDotMember(left)
		} else if self.Match("[") {
			left = self.ParseBracketMember(left)
		} else {
			break
		}
	}

	return left
}

func (self *_parser) ParseLeftHandSideExpressionAllowCall() _node {

	var left _node
	if self.Match("new") {
		left = self.ParseNewExpression()
	} else {
		left = self.ParsePrimaryExpression()
	}

	for {
		if self.Match(".") {
			left = self.ParseDotMember(left)
		} else if self.Match("[") {
			left = self.ParseBracketMember(left)
		} else if self.Match("(") {
			left = self.ParseCallExpression(left)
		} else {
			break
		}
	}

	return left
}

func (self *_parser) ParsePostfixExpression() _node {
	left := self.ParseLeftHandSideExpressionAllowCall()

	// TODO Need better syntax checking here
	// Strictness checking, etc.

	switch token := self.Peek(); token.Kind {
	case "++", "--": // Postfix, either =++ or =--
		if self.Match("\n") { // TODO Why?
			break
		}
		switch left.Type() {
		case nodeIdentifier, nodeDotMember, nodeBracketMember:
		default:
			panic(self.History(-1).newSyntaxError("Invalid left-hand side in assignment"))
		}
		node := newUnaryOperationNode("="+self.Consume(), left)
		self.markNode(node)
		return node
	}

	return left
}

func (self *_parser) ParseUnaryExpression() _node {

	// TODO Need better syntax checking here
	// Strictness checking, basically (trying to delete a non-reference, etc.)

	switch token := self.Peek(); token.Kind {
	case "+", "-", "!", "~":
		node := newUnaryOperationNode(self.Consume(), self.ParseUnaryExpression())
		self.markNode(node)
		return node
	case "++", "--": // Prefix, either ++= or --=
		operation := self.Consume()
		left := self.ParseUnaryExpression()
		switch left.Type() {
		case nodeIdentifier, nodeDotMember, nodeBracketMember:
		default:
			panic(self.History(-1).newSyntaxError("Invalid left-hand side in assignment"))
		}
		node := newUnaryOperationNode(operation+"=", left)
		self.markNode(node)
		return node
	case "delete", "void", "typeof":
		node := newUnaryOperationNode(self.Consume(), self.ParseUnaryExpression())
		self.markNode(node)
		return node
	}

	return self.ParsePostfixExpression()
}

func (self *_parser) ParseMultiplicativeExpression() _node {
	left := self.ParseUnaryExpression()

REPEAT:
	switch self.Peek().Kind {
	case "*", "/", "%":
		left = newBinaryOperationNode(self.Consume(), left, self.ParseUnaryExpression())
		self.markNode(left)
		goto REPEAT
	}

	return left
}

func (self *_parser) ParseAdditiveExpression() _node {
	left := self.ParseMultiplicativeExpression()

REPEAT:
	switch self.Peek().Kind {
	case "+", "-":
		left = newBinaryOperationNode(self.Consume(), left, self.ParseMultiplicativeExpression())
		self.markNode(left)
		goto REPEAT
	}

	return left
}

func (self *_parser) ParseShiftExpression() _node {
	left := self.ParseAdditiveExpression()

REPEAT:
	switch self.Peek().Kind {
	case "<<", ">>", ">>>":
		left = newBinaryOperationNode(self.Consume(), left, self.ParseAdditiveExpression())
		self.markNode(left)
		goto REPEAT
	}
	return left
}

func (self *_parser) ParseRelationalExpression() _node {
	previousAllowIn := self.Scope().AllowIn
	self.Scope().AllowIn = true
	left := self.ParseShiftExpression()
	self.Scope().AllowIn = previousAllowIn // TODO This should be deferred

	switch self.Peek().Kind {
	case "<", ">", "<=", ">=":
		node := newComparisonNode(self.Consume(), left, self.ParseRelationalExpression())
		self.markNode(node)
		return node
	case "instanceof":
		node := newBinaryOperationNode(self.Consume(), left, self.ParseRelationalExpression())
		self.markNode(node)
		return node
	case "in":
		if !self.Scope().AllowIn {
			return left
		}
		node := newBinaryOperationNode(self.Consume(), left, self.ParseRelationalExpression())
		self.markNode(node)
		return node

	}

	return left
}

func (self *_parser) ParseEqualityExpression() _node {
	left := self.ParseRelationalExpression()

REPEAT:
	switch self.Peek().Kind {
	case "==", "!=", "===", "!==":
		left = newComparisonNode(self.Consume(), left, self.ParseRelationalExpression())
		self.markNode(left)
		goto REPEAT
	}

	return left
}

func (self *_parser) ParseBitwiseANDExpression() _node {
	left := self.ParseEqualityExpression()

	for self.Match("&") {
		left = newBinaryOperationNode(self.Consume(), left, self.ParseEqualityExpression())
		self.markNode(left)
	}

	return left
}

func (self *_parser) ParseBitwiseXORExpression() _node {
	left := self.ParseBitwiseANDExpression()

	for self.Match("^") {
		left = newBinaryOperationNode(self.Consume(), left, self.ParseBitwiseANDExpression())
		self.markNode(left)
	}

	return left
}

func (self *_parser) ParseBitwiseORExpression() _node {
	left := self.ParseBitwiseXORExpression()

	for self.Match("|") {
		left = newBinaryOperationNode(self.Consume(), left, self.ParseBitwiseXORExpression())
		self.markNode(left)
	}

	return left
}

func (self *_parser) ParseLogicalANDExpression() _node {
	left := self.ParseBitwiseORExpression()

	for self.Match("&&") {
		left = newBinaryOperationNode(self.Consume(), left, self.ParseBitwiseORExpression())
		self.markNode(left)
	}

	return left
}

func (self *_parser) ParseLogicalORExpression() _node {
	left := self.ParseLogicalANDExpression()

	for self.Match("||") {
		left = newBinaryOperationNode(self.Consume(), left, self.ParseLogicalANDExpression())
		self.markNode(left)
	}

	return left
}

func (self *_parser) ParseConditionlExpression() _node {
	left := self.ParseLogicalORExpression()

	if self.Accept("?") {
		consequent := self.ParseAssignmentExpression()
		self.Expect(":")
		node := newConditionalNode(left, consequent, self.ParseAssignmentExpression())
		self.markNode(node)
		return node
	}

	return left
}

func (self *_parser) ParseAssignmentExpression() _node {
	left := self.ParseConditionlExpression()
	if self.matchAssignment() {
		switch left.Type() {
		case nodeIdentifier, nodeDotMember, nodeBracketMember:
		default:
			panic(newReferenceError("Invalid left-hand side in assignment"))
		}
		left = newAssignmentNode(self.Consume(), left, self.ParseAssignmentExpression())
		self.markNode(left)
	}
	return left
}

func (self *_parser) ParseExpression() _node {
	left := self.ParseAssignmentExpression()

	if self.Match(",") {
		nodeList := []_node{left}
		for {
			if !self.Accept(",") {
				break
			}
			nodeList = append(nodeList, self.ParseAssignmentExpression())
		}
		node := newCommaNode(nodeList)
		self.markNode(node)
		return node
	}

	return left
}
