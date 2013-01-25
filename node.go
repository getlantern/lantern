package otto

import (
	"fmt"
	"reflect"
	"sort"
	"strings"
)

type _node interface {
	Type() _nodeType
	String() string
	setPosition(int)
	position() int
}

type _nodeType int

func (self _nodeType) Type() _nodeType {
	return self
}

type _node_ struct {
	_nodeType
	Line int // Line in the source
}

func (self *_node_) setPosition(Line int) {
	self.Line = Line
}

func (self *_node_) position() int {
	return self.Line
}

const (
	nodeEmpty _nodeType = iota
	nodeCall
	nodeBlock
	nodeFunction
	nodeCatch
	nodeProgram
	nodeSwitch
	nodeCase
	nodeTryCatch
	nodeWhile
	nodeDoWhile
	nodeString
	nodeBoolean
	nodeNull
	nodeAssignment
	nodeUnaryOperation
	nodeBinaryOperation
	nodeBreak
	nodeContinue
	nodeComparison
	nodeIdentifier
	nodeReturn
	nodeIf
	nodeNumber
	nodeThrow
	nodeVariableDeclaration
	nodeVariableDeclarationList
	nodeWith
	nodeFor
	nodeForIn
	nodeDotMember
	nodeBracketMember

	nodeObject
	nodeObjectProperty

	nodeArray
	nodeRegExp

	nodeNew

	nodeValue
	nodeThis
	nodeComma
)

// _labelSet

type _labelSet map[string]bool

func (self _labelSet) label(target string) string {
	tmp := []string{}
	for label, _ := range self {
		if len(label) == 0 {
			continue
		}
		tmp = append(tmp, label)
	}
	sort.Strings(tmp)
	tmp = append([]string{target}, tmp...)
	return strings.Join(tmp, ":")
}

// _declaration

type _declaration struct {
	Name       string
	Definition _node
}

// _node*String

func _fmtNodeSliceString(input interface{}) string {
	result := []string{}
	inputValue := reflect.ValueOf(input)
	for i := 0; i < inputValue.Len(); i++ {
		result = append(result, fmt.Sprintf("%v", inputValue.Index(i).Interface()))
	}
	if len(result) == 0 {
		return "_"
	}
	return strings.Join(result, " ")
}

func fmtNodeString(argument0 interface{}, arguments ...interface{}) string {
	if _, yes := argument0.(string); yes {
		return _fmtNodeString(argument0.(string), arguments...)
	}

	result := ""

	if argument0 != nil {
		result = fmt.Sprintf("%v", argument0)
	} else if len(arguments) > 0 {
		result = fmt.Sprintf("%v", arguments[0])
	}

	return result
}

func _fmtNodeString(head string, arguments ...interface{}) string {
	tail := []interface{}{}
	for _, argument := range arguments {
		value := argument
		if reflect.ValueOf(argument).Kind() == reflect.Slice {
			tail = append(tail, _fmtNodeSliceString(value))
		} else {
			tail = append(tail, value)
		}
	}
	result := fmt.Sprintf(head, tail...)
	if false && result != "{}" {
		result = fmt.Sprintf("{ %s }", result)
	}
	return result
}
