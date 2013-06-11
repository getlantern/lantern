package otto

import (
	"fmt"
	"strings"
)

const ottoDebug = false

const endOfFile = -1
const startOfFile = -2

func mustParse(source string) *_programNode {
	parser := newParser()
	parser.lexer.Source = source
	return parser.Parse()
}

func parse(source string) (result *_programNode, err interface{}) {
	defer func() {
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case *_syntaxError, _error:
				err = caught
				return
			}
			panic(caught)
		}
	}()
	parser := newParser()
	parser.lexer.Source = source
	return parser.Parse(), nil
}

func init() {

	// 2-character
	// <= >= == != ++ -- << >> && ||
	// += -= *= %= &= |= ^= /=
	for _, value := range "<>=!+-*%&|^/" {
		punctuatorTable[string(value)+"="] = true
	}

	for _, value := range "+-<>&|" {
		punctuatorTable[string(value)+string(value)] = true
	}

	// 1-character
	for _, value := range "[]<>+-*%&|^!~?:=/;{},()" {
		punctuatorTable[string(value)] = true
	}
}

type _parser struct {
	lexer   _lexer
	Stack   [](*_sourceScope)
	history []_token
}

func newParser() *_parser {
	self := &_parser{
		history: make([]_token, 0, 4),
	}
	self.lexer.readIn = make([]rune, 0)
	return self
}

func (self *_parser) Consume() string {
	return self.Next().Text
}

type _sourceScope struct {
	VariableList []_declaration
	FunctionList []_declaration
	labelSet     _labelSet
	AllowIn      bool
	InFunction   bool
	InSwitch     bool
	InIteration  bool
}

func (self *_sourceScope) AddVariable(name string) {
	self.VariableList = append(self.VariableList, _declaration{name, nil})
}

func (self *_sourceScope) AddFunction(name string, definition _node) {
	self.FunctionList = append(self.FunctionList, _declaration{name, definition})
}

func newSourceScope() *_sourceScope {
	self := &_sourceScope{
		labelSet: _labelSet{},
		AllowIn:  true,
	}
	return self
}

func (self *_sourceScope) HasLabel(name string) bool {
	_, exists := self.labelSet[name]
	return exists
}

func (self *_parser) EnterScope() {
	scope := newSourceScope()
	self.Stack = append(self.Stack, scope)
}

func (self *_parser) LeaveScope() {
	self.Stack = self.Stack[:len(self.Stack)-1]
}

func (self *_parser) Scope() *_sourceScope {
	return self.Stack[len(self.Stack)-1]
}

func (self *_parser) Accept(kind string) bool {
	if kind == "\n" {
		// This is a PeekLineSkip, except we
		// retain the adjusted lexer if we really
		// skipped a line
		lexerCopy := self.lexer.Copy()
		didSkip := lexerCopy.ScanLineSkip()
		if didSkip {
			self.lexer = *lexerCopy
		}
		return didSkip
	}
	if self.Match(kind) {
		self.Next()
		return true
	}
	return false
}

func (self *_parser) Match(kind string) bool {
	if kind == "\n" {
		return self.PeekLineSkip()
	}
	return self.Peek().Kind == kind
}

func (self *_parser) Expect(kind string) {
	token := self.Next()
	if token.Kind != kind {
		panic(self.Unexpected(token))
		//panic(fmt.Sprintf("Expect %s but got %s (%s)", kind, token.Kind, token.Text))
	}
}

var assignmentTable map[string]string = map[string]string{}

func init() {
	for _, value := range strings.Fields("= *= /= %= += -= <<= >>= >>>= &= ^= |=") {
		operator := value[:len(value)-1]
		assignmentTable[value] = operator
	}
}

func (self *_parser) matchAssignment() bool {
	if _, exists := assignmentTable[self.Peek().Kind]; exists {
		return true
	}
	return false
}

func (self *_parser) ConsumeNull() *_valueNode {
	node := newNullNode(self.Next().Text)
	self.markNode(node)
	return node
}

func (self *_parser) throwUnexpectedError(token _token) {
	if futureKeywordTable[token.Kind] {
		panic(token.newSyntaxError("Unexpected reserved word"))
	}
	panic(token.newSyntaxError("Unexpected token %s", token.Kind))
}

func (self *_parser) ConsumeIdentifier() *_identifierNode {
	token := self.Next()
	if token.Kind != "identifier" {
		self.throwUnexpectedError(token) // panic
	}
	node := newIdentifierNode(token.Text)
	self.markNode(node)
	return node
}

func (self *_parser) ConsumeString() *_valueNode {
	node := newStringNode(self.Next().Text)
	self.markNode(node)
	return node
}

func (self *_parser) ConsumeBoolean() *_valueNode {
	node := newBooleanNode(self.Next().Text)
	self.markNode(node)
	return node
}

func (self *_parser) ConsumeNumber() *_valueNode {
	node := newNumberNode(self.Next().Text)
	self.markNode(node)
	return node
}

func (self *_parser) ConsumeSemicolon() {

	if self.Accept(";") {
		return
	}

	if self.Accept("\n") {
		return
	}

	if self.Accept(";") {
		return
	}

	if !self.Match("EOF") && !self.Match("}") {
		panic(self.Unexpected(self.Peek()))
	}

	return
}

func (self *_parser) ScanRegularExpression() _token {
	token := self.lexer.ScanRegularExpression()
	self.history = append(self.history, token)
	if len(self.history) > 4 {
		self.history = self.history[len(self.history)-4:]
	}
	return token
}

func (self *_parser) Next() _token {
	token := self.lexer.Scan()
	self.history = append(self.history, token)
	if len(self.history) > 4 {
		self.history = self.history[len(self.history)-4:]
	}
	return token
}

func (self *_parser) History(index int) _token {
	if 0 > index {
		index = len(self.history) + index
	}
	if index >= len(self.history) {
		panic(fmt.Errorf("Index %d is out of range for history (%d)", index, len(self.history)))
	}
	return self.history[index]
}

func (self *_parser) PeekLineSkip() bool {
	return self.lexer.Copy().ScanLineSkip()
}

func (self *_parser) Peek() _token {
	return self.lexer.Copy().Scan()
}

func (self *_parser) Parse() *_programNode {
	self.EnterScope()
	defer self.LeaveScope()

	node := newProgramNode()
	node.Body = self.parseStatementUntil(func() bool {
		return self.Match("EOF")
	})
	node.VariableList = self.Scope().VariableList
	node.FunctionList = self.Scope().FunctionList

	return node
}

func (self *_parser) ParseAsFunction() *_programNode {
	self.EnterScope()
	defer self.LeaveScope()
	self.Scope().InFunction = true

	node := newProgramNode()
	node.Body = self.parseStatementUntil(func() bool {
		return self.Match("EOF")
	})
	node.VariableList = self.Scope().VariableList
	node.FunctionList = self.Scope().FunctionList

	return node
}

func (self *_parser) Unexpected(token _token) *_syntaxError {
	switch token.Kind {
	case "EOF":
		return self.History(-1).newSyntaxError("Unexpected end of input")
	case "illegal":
		return token.newSyntaxError("Unexpected token ILLEGAL (%s)", token.Text)
	}
	return token.newSyntaxError("Unexpected token %s", token.Text)
}

func (self *_parser) markNode(node _node) {
	node.setPosition(self.lexer.lineCount)
}

func isIdentifierName(token _token) bool {
	switch token.Kind {
	case "identifier", "boolean":
		return true
	}
	return keywordTable[token.Kind]
}
