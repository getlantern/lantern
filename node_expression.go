package otto

import (
	"fmt"
)

type _arrayNode struct {
	_nodeType
	_node_
	nodeList []_node
}

func newArrayNode(nodeList []_node) *_arrayNode {
	return &_arrayNode{
		_nodeType: nodeArray,
		nodeList:  nodeList,
	}
}

func (self *_arrayNode) String() string {
	if len(self.nodeList) == 0 {
		return "[]"
	}
	return fmtNodeString("[ %s ]", self.nodeList)
}

type _assignmentNode struct {
	_nodeType
	_node_
	Assignment string
	Operator   string
	Left       _node
	Right      _node
}

func newAssignmentNode(assignment string, left _node, right _node) *_assignmentNode {
	return &_assignmentNode{
		_nodeType:  nodeAssignment,
		Assignment: assignment,
		Operator:   assignmentTable[assignment],
		Left:       left,
		Right:      right,
	}
}

func (self _assignmentNode) String() string {
	return fmt.Sprintf("{ %s= %s %s }", self.Operator, self.Left, self.Right)
}

type _binaryOperationNode struct {
	_nodeType
	_node_
	Operator string
	Left     _node
	Right    _node
}

func newBinaryOperationNode(operator string, left _node, right _node) *_binaryOperationNode {
	return &_binaryOperationNode{
		_nodeType: nodeBinaryOperation,
		Operator:  operator,
		Left:      left,
		Right:     right,
	}
}

func (self _binaryOperationNode) String() string {
	return fmt.Sprintf("{ %s %s %s }", self.Operator, self.Left, self.Right)
}

type _callNode struct {
	_nodeType
	_node_
	Callee       _node
	ArgumentList []_node
}

func newCallNode(callee _node) *_callNode {
	return &_callNode{
		_nodeType:    nodeCall,
		Callee:       callee,
		ArgumentList: []_node{},
	}
}

func (self _callNode) String() string {
	return fmtNodeString("{ <call> %s %s }", self.Callee, self.ArgumentList)
}

type _commaNode struct {
	_nodeType
	_node_
	Sequence []_node
}

func newCommaNode(sequence []_node) *_commaNode {
	return &_commaNode{
		_nodeType: nodeComma,
		Sequence:  sequence,
	}
}

func (self _commaNode) String() string {
	return fmtNodeString("{ %s }", self.Sequence)
}

type _comparisonNode struct {
	_nodeType
	_node_
	Comparator string
	Left       _node
	Right      _node
}

func newComparisonNode(comparator string, left _node, right _node) *_comparisonNode {
	return &_comparisonNode{
		_nodeType:  nodeComparison,
		Comparator: comparator,
		Left:       left,
		Right:      right,
	}
}

func (self _comparisonNode) String() string {
	return fmt.Sprintf("{ %s %s %s }", self.Comparator, self.Left, self.Right)
}

type _conditionalNode struct {
	_nodeType
	_node_
	Test       _node
	Consequent _node
	Alternate  _node
}

func newConditionalNode(test _node, consequent _node, alternate _node) *_conditionalNode {
	return &_conditionalNode{
		Test:       test,
		Consequent: consequent,
		Alternate:  alternate,
	}
}

func (self _conditionalNode) String() string {
	return fmtNodeString("{ ?: %s %s %s }", self.Test, self.Consequent, self.Alternate)
}

type _functionNode struct {
	_nodeType
	_node_
	_declaration         bool
	ParameterList        []string
	Body                 []_node
	VariableList         []_declaration
	FunctionList         []_declaration
	ArgumentsIsParameter bool // A hint that "arguments" exists as a parameter
}

func newFunctionNode() *_functionNode {
	return &_functionNode{
		_nodeType: nodeFunction,
	}
}

func (self _functionNode) String() string {
	return fmtNodeString("{ <function> %s }", self.Body)
}

func (self *_functionNode) AddParameter(identifier string) {
	self.ParameterList = append(self.ParameterList, identifier)
}

type _identifierNode struct {
	_nodeType
	_node_
	Value string
}

func newIdentifierNode(value string) *_identifierNode {
	return &_identifierNode{
		_nodeType: nodeIdentifier,
		Value:     value,
	}
}

func (self *_identifierNode) String() string {
	return self.Value
}

type _dotMemberNode struct {
	_nodeType
	_node_
	Target _node
	Member string
}

func newDotMemberNode(target _node, member string) *_dotMemberNode {
	return &_dotMemberNode{
		_nodeType: nodeDotMember,
		Target:    target,
		Member:    member,
	}
}

func (self *_dotMemberNode) String() string {
	return fmtNodeString("{ . %s %s }", self.Target, self.Member)
}

type _bracketMemberNode struct {
	_nodeType
	_node_
	Target _node
	Member _node
}

func newBracketMemberNode(target _node, member _node) *_bracketMemberNode {
	return &_bracketMemberNode{
		_nodeType: nodeBracketMember,
		Target:    target,
		Member:    member,
	}
}

func (self *_bracketMemberNode) String() string {
	return fmtNodeString("{ [ %s %s }", self.Target, self.Member)
}

type _newNode struct {
	_nodeType
	_node_
	Callee       _node
	ArgumentList []_node
}

func newNewNode(callee _node) *_newNode {
	return &_newNode{
		_nodeType:    nodeNew,
		Callee:       callee,
		ArgumentList: []_node{},
	}
}

func (self _newNode) String() string {
	return fmtNodeString("{ <new> %s %s }", self.Callee, self.ArgumentList)
}

type _objectNode struct {
	_nodeType
	_node_
	propertyList []*_objectPropertyNode
}

func newObjectNode() *_objectNode {
	return &_objectNode{
		_nodeType: nodeObject,
	}
}

func (self *_objectNode) AddProperty(property *_objectPropertyNode) {
	self.propertyList = append(self.propertyList, property)
}

func (self *_objectNode) String() string {
	if len(self.propertyList) == 0 {
		return "{[]}"
	}
	return fmtNodeString("{[ %s ]}", self.propertyList)
}

type _objectPropertyNode struct {
	_nodeType
	_node_
	Key   string
	Value _node
}

func newObjectPropertyNode(key string, value _node) *_objectPropertyNode {
	return &_objectPropertyNode{
		_nodeType: nodeObjectProperty,
		Key:       key,
		Value:     value,
	}
}

func (self *_objectPropertyNode) String() string {
	return fmtNodeString("{ %s: %s }", self.Key, self.Value)
}

type _regExpNode struct {
	_nodeType
	_node_
	Pattern string
	Flags   string
}

func newRegExpNode(pattern string, flags string) *_regExpNode {
	return &_regExpNode{
		_nodeType: nodeRegExp,
		Pattern:   pattern,
		Flags:     flags,
	}
}

func (self *_regExpNode) String() string {
	return fmtNodeString("{ /%s/%s }", self.Pattern, self.Flags)
}

type _thisNode struct {
	_nodeType
	_node_
}

func newThisNode() *_thisNode {
	return &_thisNode{
		_nodeType: nodeThis,
	}
}

func (self *_thisNode) String() string {
	return "this"
}

type _unaryOperationNode struct {
	_nodeType
	_node_
	Operator string
	Target   _node
}

func newUnaryOperationNode(operator string, target _node) *_unaryOperationNode {
	return &_unaryOperationNode{
		_nodeType: nodeUnaryOperation,
		Operator:  operator,
		Target:    target,
	}
}

func (self _unaryOperationNode) String() string {
	return fmt.Sprintf("{ %s %s }", self.Operator, self.Target)
}

type _valueNodeType int

const (
	valueNodeUndefined _valueNodeType = iota
	valueNodeNull
	valueNodeBoolean
	valueNodeString
	valueNodeNumber
)

type _valueNode struct {
	_nodeType
	_node_
	Value Value
	Text  string
	Kind  _valueNodeType
}

func newUndefinedNode() *_valueNode {
	return &_valueNode{
		_nodeType: nodeValue,
		Text:      "undefined",
		Value:     UndefinedValue(),
		Kind:      valueNodeUndefined,
	}
}

func newNullNode(text string) *_valueNode {
	return &_valueNode{
		_nodeType: nodeValue,
		Text:      text,
		Value:     NullValue(),
		Kind:      valueNodeNull,
	}
}

func newBooleanNode(text string) *_valueNode {
	node := &_valueNode{
		_nodeType: nodeValue,
		Text:      text,
		Kind:      valueNodeBoolean,
	}
	switch text {
	case "true":
		node.Value = TrueValue()
	case "false":
		node.Value = FalseValue()
	default:
		throwHereBeDragons()
	}
	return node
}

func newNumberNode(text string) *_valueNode {
	// TODO Can there be an error here? Is NaN a good catch-all?
	value := stringToFloat(text)
	//value, err := strconv.ParseFloat(text, 64)
	//if err != nil {
	//    throwHereBeDragons(error)
	//}
	return &_valueNode{
		_nodeType: nodeValue,
		Text:      text,
		Value:     toValue_float64(value),
		Kind:      valueNodeNumber,
	}
}

func newStringNode(text string) *_valueNode {
	return &_valueNode{
		_nodeType: nodeValue,
		Text:      text,
		Value:     toValue_string(text),
		Kind:      valueNodeString, // Slightly less ugh, but still ugh
	}
}

func (self *_valueNode) String() string {
	if self.Kind == valueNodeString {
		return fmt.Sprintf("\"%s\"", self.Text)
	}
	return fmt.Sprintf("%s", self.Text)
}
