package otto

import ()

func (self *_parser) ParseStatement() _node {

	switch self.Peek().Kind {
	case ";":
		self.Next()
		node := newEmptyNode()
		self.markNode(node)
		return node
	case "if":
		return self.ParseIf()
	case "do":
		return self.ParseDoWhile()
	case "while":
		return self.ParseWhile()
	case "for":
		return self.ParseForOrForIn()
	case "continue":
		return self.ParseContinue()
	case "with":
		return self.ParseWith()
	case "break":
		return self.ParseBreak()
	case "{":
		return self.ParseBlock()
	case "var":
		return self.ParseVariableStatement()
	case "function":
		self.ParseFunctionDeclaration()
		// TODO Should be FunctionDeclarationStatement
		node := newEmptyNode()
		self.markNode(node)
		return node
	case "switch":
		return self.ParseSwitch()
	case "return":
		return self.ParseReturnStatement()
	case "throw":
		return self.ParseThrow()
	case "try":
		return self.ParseTryCatch()
	}

	expression := self.ParseExpression()

	if identifier, yes := expression.(*_identifierNode); yes && self.Accept(":") {
		labelSet := self.Scope().labelSet
		label := identifier.Value
		if labelSet[label] {
			panic(self.History(-2).newSyntaxError("Label '%s' has already been declared", label))
		}
		labelSet[label] = true
		statement := self.ParseStatement()
		delete(labelSet, label)
		{
			labelSet = nil
			switch node := statement.(type) {
			case *_blockNode:
				labelSet = node.labelSet
			case *_doWhileNode:
				labelSet = node.labelSet
			case *_whileNode:
				labelSet = node.labelSet
			case *_switchNode:
				labelSet = node.labelSet
			case *_forNode:
				labelSet = node.labelSet
			case *_forInNode:
				labelSet = node.labelSet
			}
			if labelSet != nil {
				labelSet[label] = true
			}
		}
		return statement
	}

	self.ConsumeSemicolon()

	return expression
}

//func (self *_parser) parseSource() []_node {
//    nodeList := self.parseStatementUntil(func() bool {
//        return self.Match("EOF")
//    });
//    return self.ParseStatement()
//}

func (self *_parser) parseSourceElement() _node {
	return self.ParseStatement()
}

func (self *_parser) ParseTryCatch() _node {
	self.Expect("try")

	node := newTryCatchNode(self.ParseBlock())

	found := false
	if self.Accept("catch") {
		self.Expect("(")
		identifier := self.ConsumeIdentifier().Value
		self.Expect(")")
		node.Catch = newCatchNode(identifier, self.ParseBlock())
		found = true
	}

	if self.Accept("finally") {
		node.Finally = self.ParseBlock()
		found = true
	}

	if !found {
		panic(self.Peek().newSyntaxError("Missing catch or finally after try"))
	}

	return node
}

func (self *_parser) ParseWith() _node {
	self.Expect("with")

	return newWithNode(self.ParseExpression(), self.ParseStatement())
}

func (self *_parser) ParseContinue() _node {
	result := self.ParseContinueBreak("continue", func(kind string) _node { return newContinueNode(kind) })
	if self.Scope().InIteration {
		return result
	}
	panic(self.Peek().newSyntaxError("Illegal continue statement"))
}

func (self *_parser) ParseBreak() _node {
	result := self.ParseContinueBreak("break", func(kind string) _node { return newBreakNode(kind) })
	scope := self.Scope()
	if scope.InIteration || scope.InSwitch {
		return result
	}
	panic(self.Peek().newSyntaxError("Illegal break statement"))
}

func (self *_parser) ParseContinueBreak(kind string, _newNode func(string) _node) _node {
	self.Expect(kind)

	if self.Accept(";") || self.Accept("\n") {
		return _newNode("")
	}

	label := ""
	if self.Match("identifier") {
		identifier := self.ConsumeIdentifier()
		label = identifier.Value
		if !self.Scope().HasLabel(label) {
			panic(self.History(-1).newSyntaxError("Undefined label '%s'", label))
		}
	}

	self.ConsumeSemicolon()

	return _newNode(label)
}

func (self *_parser) parseInFunction(parse func() _node) _node {
	in := self.Scope().InFunction
	self.Scope().InFunction = true
	defer func() {
		self.Scope().InFunction = in
	}()
	return parse()
}

func (self *_parser) parseInSwitch(parse func() _node) _node {
	in := self.Scope().InSwitch
	self.Scope().InSwitch = true
	defer func() {
		self.Scope().InSwitch = in
	}()
	return parse()
}

func (self *_parser) parseInIteration(parse func() _node) []_node {
	in := self.Scope().InIteration
	self.Scope().InIteration = true
	defer func() {
		self.Scope().InIteration = in
	}()
	switch node := parse().(type) {
	case *_blockNode:
		return node.Body
	default:
		return []_node{node}
	}
	panic("")
}

func (self *_parser) ParseDoWhile() _node {
	self.Expect("do")
	body := self.parseInIteration(func() _node {
		return self.ParseStatement()
	})
	self.Expect("while")
	self.Expect("(")
	test := self.ParseExpression()
	self.Expect(")")

	node := newDoWhileNode(test, body)
	node.labelSet[""] = true
	return node
}

func (self *_parser) ParseWhile() _node {
	self.Expect("while")
	self.Expect("(")
	test := self.ParseExpression()
	self.Expect(")")
	body := self.parseInIteration(func() _node {
		return self.ParseStatement()
	})

	node := newWhileNode(test, body)
	node.labelSet[""] = true
	return node
}

func (self *_parser) ParseIf() _node {
	self.Expect("if")
	self.Expect("(")
	node := newIfNode(self.ParseExpression(), nil)
	self.Expect(")")
	node.Consequent = self.ParseStatement()
	if self.Accept("else") {
		node.Alternate = self.ParseStatement()
	}

	return node
}

func (self *_parser) parseStatementUntil(stop func() bool) []_node {
	list := []_node{}
	for {
		if stop() {
			break
		}
		list = append(list, self.ParseStatement())
	}
	return list
}

func (self *_parser) ParseBlock() *_blockNode {
	node := newBlockNode()
	self.markNode(node)

	self.Expect("{")
	node.Body = self.parseStatementUntil(func() bool {
		return self.Accept("}")
	})

	return node
}

func (self *_parser) ParseReturnStatement() _node {
	self.Expect("return")

	if !self.Scope().InFunction {
		panic(self.History(-1).newSyntaxError("Illegal return statement"))
	}

	node := newReturnNode()
	self.markNode(node)

	if self.Match("\n") {
		return node
	}

	if !self.Match(";") {
		if !self.Match("}") && !self.Match("EOF") {
			node.Argument = self.ParseExpression()
		}
	}

	self.ConsumeSemicolon()

	return node
}

func (self *_parser) ParseThrow() _node {
	self.Expect("throw")

	if self.Match("\n") {
		// TODO Better error message
		panic(self.Peek().newSyntaxError("Illegal newline after throw"))
	}

	node := newThrowNode(self.ParseExpression())
	self.markNode(node)

	self.ConsumeSemicolon()

	return node
}

func (self *_parser) ParseSwitch() _node {
	self.Expect("switch")

	self.Expect("(")
	discriminant := self.ParseExpression()
	self.Expect(")")

	switchNode := newSwitchNode(discriminant)
	self.markNode(switchNode)

	self.Expect("{")

	self.parseInSwitch(func() _node {
		for i := 0; true; i++ {
			if self.Accept("}") {
				break
			}

			result := self.ParseCase()
			if result.Test == nil {
				if switchNode.Default != -1 {
					panic(hereBeDragons("Already saw a default:"))
				}
				switchNode.Default = i
			}
			switchNode.AddCase(result)
		}
		return nil
	})

	switchNode.labelSet[""] = true
	return switchNode
}

func (self *_parser) ParseCase() *_caseNode {

	var node *_caseNode
	if self.Accept("default") {
		node = newDefaultCaseNode()
		self.markNode(node)
	} else {
		self.Expect("case")
		node = newCaseNode(self.ParseExpression())
		self.markNode(node)
	}
	self.Expect(":")

	node.Body = self.parseStatementUntil(func() bool {
		return false ||
			self.Match("EOF") ||
			self.Match("}") ||
			self.Match("default") ||
			self.Match("case")
	})

	return node
}

func (self *_parser) ParseVariable() *_variableDeclarationNode {
	node := newVariableDeclarationNode(self.ConsumeIdentifier().Value)
	self.markNode(node)

	for _, value := range []string{"=", ":="} {
		if self.Accept(value) {
			node.Operator = value
			node.Initializer = self.ParseAssignmentExpression()
			break
		}
	}

	return node
}

func (self *_parser) ParseVariableDeclaration() *_variableDeclarationListNode {
	self.Expect("var")

	node := newVariableDeclarationListNode()
	self.markNode(node)

	for {
		variable := self.ParseVariable()
		node.VariableList = append(node.VariableList, variable)
		self.Scope().AddVariable(variable.Identifier)

		if !self.Accept(",") {
			break
		}
	}

	return node
}

func (self *_parser) ParseVariableStatement() *_variableDeclarationListNode {

	node := self.ParseVariableDeclaration()

	self.ConsumeSemicolon()

	return node
}

func (self *_parser) ParseFunction(declare bool) _node {

	self.Expect("function")

	functionNode := newFunctionNode()
	self.markNode(functionNode)

	identifier := ""
	if self.Match("identifier") {
		identifier = self.ConsumeIdentifier().Value
		if declare {
			self.Scope().AddFunction(identifier, functionNode)
		}
	} else if declare {
		// Trigger a panic, because we really should see
		// an identifier here
		self.Expect("identifier")
	}

	token := self.Peek()
	if token.Kind != "(" {
		panic(self.Unexpected(token))
	}

	self.Expect("(")
	for !self.Accept(")") {
		identifier := self.ConsumeIdentifier().Value
		functionNode.AddParameter(identifier)
		if identifier == "arguments" {
			functionNode.ArgumentsIsParameter = true
		}
		if !self.Match(")") {
			self.Expect(",")
		}
	}

	{
		self.EnterScope()
		if !declare && identifier != "" {
			self.Scope().AddFunction(identifier, functionNode)
		}
		defer self.LeaveScope()
		self.parseInFunction(func() _node {
			functionNode.Body = self.ParseBlock().Body
			return nil
		})
		functionNode.VariableList = self.Scope().VariableList
		functionNode.FunctionList = self.Scope().FunctionList
	}

	return functionNode
}

/*func (self *_parser) ParseFunctionParameterList() []string {*/
/*    parameterList := []string{}*/

/*    for !self.Match("EOF") {*/
/*        identifier := self.ConsumeIdentifier().Value*/
/*        parameterList = append(parameterList, identifier)*/
/*    }*/

/*    return parameterList*/
/*}*/

func (self *_parser) ParseFunctionDeclaration() {
	self.ParseFunction(true)
}

func (self *_parser) parseForIn(into _node) *_forInNode {

	// Already have consumed "<into> in"

	source := self.ParseExpression()
	self.Expect(")")

	body := self.parseInIteration(func() _node {
		return self.ParseStatement()
	})

	node := newForInNode(into, source, body)
	self.markNode(node)
	node.labelSet[""] = true
	return node
}

func (self *_parser) parseFor(initial _node) *_forNode {

	// Already have consumed "<initial> ;"

	var test, update _node

	if !self.Match(";") {
		test = self.ParseExpression()
	}
	self.Expect(";")

	if !self.Match(")") {
		update = self.ParseExpression()
	}
	self.Expect(")")

	body := self.parseInIteration(func() _node {
		return self.ParseStatement()
	})

	node := newForNode(initial, test, update, body)
	self.markNode(node)
	node.labelSet[""] = true
	return node
}

func (self *_parser) ParseForOrForIn() _node {
	self.Expect("for")
	self.Expect("(")

	var left _node

	isIn := false
	if !self.Match(";") {
		previousAllowIn := self.Scope().AllowIn
		self.Scope().AllowIn = false
		if self.Match("var") {
			declarationList := self.ParseVariableDeclaration()
			if len(declarationList.VariableList) == 1 && self.Accept("in") {
				isIn = true
				// We only want (there should be only) one _declaration
				// (12.2 Variable Statement)
				left = declarationList.VariableList[0]
			} else {
				left = declarationList
			}
		} else {
			left = self.ParseExpression()
			isIn = self.Accept("in")
		}
		self.Scope().AllowIn = previousAllowIn
	}

	if !isIn {
		self.Expect(";")
		return self.parseFor(left)
	} else {
		switch left.Type() {
		case nodeIdentifier, nodeDotMember, nodeBracketMember, nodeVariableDeclaration:
		default:
			panic(self.History(-1).newSyntaxError("Invalid left-hand side in for-in"))
		}
	}

	return self.parseForIn(left)
}
