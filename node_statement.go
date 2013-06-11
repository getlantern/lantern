package otto

import (
	"fmt"
)

type _blockNode struct {
	_nodeType
	_node_
	Body     []_node
	labelSet _labelSet
}

func newBlockNode() *_blockNode {
	return &_blockNode{
		_nodeType: nodeBlock,
		labelSet:  _labelSet{},
	}
}

func (self _blockNode) String() string {
	if len(self.Body) == 0 {
		return "{}"
	}
	return fmtNodeString("{ %s }", self.Body)
}

type _breakNode struct {
	_nodeType
	_node_
	Target string
}

func newBreakNode(target string) *_breakNode {
	return &_breakNode{
		_nodeType: nodeBreak,
		Target:    target,
	}
}

func (self _breakNode) String() string {
	return fmt.Sprintf("<break:%s>", self.Target)
}

type _continueNode struct {
	_nodeType
	_node_
	Target string
}

func newContinueNode(target string) *_continueNode {
	return &_continueNode{
		_nodeType: nodeContinue,
		Target:    target,
	}
}

func (self _continueNode) String() string {
	return fmt.Sprintf("<continue:%s>", self.Target)
}

type _emptyNode struct {
	_nodeType
	_node_
}

func newEmptyNode() *_emptyNode {
	return &_emptyNode{
		_nodeType: nodeEmpty,
	}
}

func (self _emptyNode) String() string {
	return ";"
}

type _iteratorNode struct {
	body []_node
}

func (self _iteratorNode) String() string {
	if len(self.body) == 0 {
		return "{}"
	}
	return fmtNodeString("{ %s }", self.body)
}

type _doWhileNode struct {
	_nodeType
	_node_
	_iteratorNode
	Test     _node
	labelSet _labelSet
}

func newDoWhileNode(test _node, body []_node) *_doWhileNode {
	self := &_doWhileNode{
		_nodeType: nodeDoWhile,
		Test:      test,
		_iteratorNode: _iteratorNode{
			body: body,
		},
		labelSet: _labelSet{},
	}
	return self
}

func (self _doWhileNode) String() string {
	return fmtNodeString("{ <%s> %s %s }", self.labelSet.label("do-while"), self.Test, self._iteratorNode)
}

type _forNode struct {
	_nodeType
	_node_
	_iteratorNode
	Initial  _node
	Test     _node
	Update   _node
	labelSet _labelSet
}

func newForNode(initial _node, test _node, update _node, body []_node) *_forNode {
	self := &_forNode{
		_nodeType: nodeFor,
		Initial:   initial,
		Test:      test,
		Update:    update,
		_iteratorNode: _iteratorNode{
			body: body,
		},
		labelSet: _labelSet{},
	}
	return self
}

func (self _forNode) String() string {

	return fmtNodeString("{ <%s> %s %s %s %s }", self.labelSet.label("for"),
		fmtNodeString(self.Initial, ";"),
		fmtNodeString(self.Test, ";"),
		fmtNodeString(self.Update, ";"),
		self._iteratorNode,
	)
}

type _forInNode struct {
	_nodeType
	_node_
	_iteratorNode
	Into     _node
	Source   _node
	labelSet _labelSet
}

func newForInNode(into _node, source _node, body []_node) *_forInNode {
	self := &_forInNode{
		_nodeType: nodeForIn,
		Into:      into,
		Source:    source,
		_iteratorNode: _iteratorNode{
			body: body,
		},
		labelSet: _labelSet{},
	}
	return self
}

func (self _forInNode) String() string {

	return fmtNodeString("{ <%s> %s in %s %s }", self.labelSet.label("for-in"),
		self.Into,
		self.Source,
		self._iteratorNode,
	)
}

type _whileNode struct {
	_nodeType
	_node_
	_iteratorNode
	Test     _node
	labelSet _labelSet
}

func newWhileNode(test _node, body []_node) *_whileNode {
	self := &_whileNode{
		_nodeType: nodeWhile,
		Test:      test,
		_iteratorNode: _iteratorNode{
			body: body,
		},
		labelSet: _labelSet{},
	}
	return self
}

func (self _whileNode) String() string {
	return fmtNodeString("{ <%s> %s %s }", self.labelSet.label("while"), self.Test, self._iteratorNode)
}

type _ifNode struct {
	_nodeType
	_node_
	Test       _node
	Consequent _node
	Alternate  _node
}

func newIfNode(test _node, consequent _node) *_ifNode {
	return &_ifNode{
		_nodeType:  nodeIf,
		Test:       test,
		Consequent: consequent,
	}
}

func newIfElseNode(test _node, consequent _node, alternate _node) *_ifNode {
	return &_ifNode{
		Test:       test,
		Consequent: consequent,
		Alternate:  alternate,
	}
}

func (self _ifNode) String() string {
	if self.Alternate != nil {
		return fmtNodeString("{ <if> %s %s %s }", self.Test, self.Consequent, self.Alternate)
	}
	return fmtNodeString("{ <if> %s %s }", self.Test, self.Consequent)
}

type _programNode struct {
	_nodeType
	_node_
	Body         []_node
	VariableList []_declaration
	FunctionList []_declaration
}

func newProgramNode() *_programNode {
	return &_programNode{
		_nodeType: nodeProgram,
	}
}

func (self _programNode) String() string {
	return fmtNodeString("{ @ %s }", self.Body)
}

func (self _programNode) toFunction(parameterList []string) *_functionNode {
	node := newFunctionNode()
	node.ParameterList = parameterList
	node.Body = self.Body
	node.VariableList = self.VariableList
	node.FunctionList = self.FunctionList
	return node
}

type _returnNode struct {
	_nodeType
	_node_
	Argument _node
}

func newReturnNode() *_returnNode {
	return &_returnNode{
		_nodeType: nodeReturn,
	}
}

func (self _returnNode) String() string {
	if self.Argument != nil {
		return fmt.Sprintf("{ <return> %s }", self.Argument)
	}
	return fmt.Sprintf("{ <return> }")
}

type _switchNode struct {
	_nodeType
	_node_
	Discriminant _node
	Default      int
	CaseList     [](*_caseNode)
	labelSet     _labelSet
}

func newSwitchNode(discriminant _node) *_switchNode {
	return &_switchNode{
		_nodeType:    nodeSwitch,
		Discriminant: discriminant,
		Default:      -1,
		labelSet:     _labelSet{},
	}
}

func (self *_switchNode) AddCase(_node *_caseNode) {
	self.CaseList = append(self.CaseList, _node)
}

func (self _switchNode) String() string {
	return fmtNodeString("{ <switch> %s %s }", self.Discriminant, self.CaseList)
}

type _caseNode struct {
	_nodeType
	_node_
	Test _node
	Body []_node
}

func newCaseNode(test _node) *_caseNode {
	return &_caseNode{
		_nodeType: nodeCase,
		Test:      test,
	}
}

func newDefaultCaseNode() *_caseNode {
	return &_caseNode{}
}

func (self _caseNode) String() string {
	if self.Test != nil {
		return fmtNodeString("{ <case> %s %s }", self.Test, self.Body)
	}
	return fmtNodeString("{ <default> %s }", self.Body)
}

type _throwNode struct {
	_nodeType
	_node_
	Argument _node
}

func newThrowNode(argument _node) *_throwNode {
	return &_throwNode{
		_nodeType: nodeThrow,
		Argument:  argument,
	}
}

func (self _throwNode) String() string {
	return fmt.Sprintf("{ <throw> %s }", self.Argument)
}

type _tryCatchNode struct {
	_nodeType
	_node_
	Try     _node
	Catch   *_catchNode
	Finally *_blockNode
}

func newTryCatchNode(try _node) *_tryCatchNode {
	return &_tryCatchNode{
		_nodeType: nodeTryCatch,
		Try:       try,
	}
}

func (self _tryCatchNode) String() string {
	return fmtNodeString("{ <try> %s %s </try> }", self.Try, func() string {
		result := ""
		if self.Catch != nil && self.Finally != nil {
			result = fmtNodeString("%s <finally> %s", self.Catch, self.Finally)
		} else if self.Catch != nil {
			result = fmtNodeString("%s", self.Catch)
		} else {
			result = fmtNodeString("<finally> %s", self.Finally)
		}
		return result
	}())
}

func (self *_tryCatchNode) AddCatch(identifier string, body *_blockNode) {
	self.Catch = newCatchNode(identifier, body)
}

type _catchNode struct {
	_nodeType
	_node_
	Identifier string
	Body       *_blockNode
}

func newCatchNode(identifier string, body *_blockNode) *_catchNode {
	return &_catchNode{
		_nodeType:  nodeCatch,
		Identifier: identifier,
		Body:       body,
	}
}

func (self _catchNode) String() string {
	return fmtNodeString("<catch> %s %s", self.Identifier, self.Body)
}

type _variableDeclarationListNode struct {
	_nodeType
	_node_
	VariableList []*_variableDeclarationNode
}

func newVariableDeclarationListNode() *_variableDeclarationListNode {
	return &_variableDeclarationListNode{
		_nodeType: nodeVariableDeclarationList,
	}
}

func (self _variableDeclarationListNode) String() string {
	return fmtNodeString("%s", self.VariableList)
}

type _variableDeclarationNode struct {
	_nodeType
	_node_
	Identifier  string
	Operator    string
	Initializer _node
}

func newVariableDeclarationNode(identifier string) *_variableDeclarationNode {
	return &_variableDeclarationNode{
		_nodeType:  nodeVariableDeclaration,
		Identifier: identifier,
	}
}

func (self _variableDeclarationNode) String() string {
	if self.Operator != "" {
		return fmtNodeString("{ <var> %s %s %s }", self.Operator, self.Identifier, self.Initializer)
	}
	return fmtNodeString("{ <var> %s }", self.Identifier)
}

type _withNode struct {
	_nodeType
	_node_
	Object _node
	Body   _node
}

func newWithNode(object _node, body _node) *_withNode {
	return &_withNode{
		_nodeType: nodeWith,
		Object:    object,
		Body:      body,
	}
}

func (self _withNode) String() string {
	return fmt.Sprintf("{ <with> %s %s }", self.Object, self.Body)
}
