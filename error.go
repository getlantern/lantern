package otto

import (
	"fmt"
	"errors"
)

type _error struct {
	Name string
	Message string
}

var messageDetail map[string]string = map[string]string{
	"notDefined": "%v is not defined",
}

func messageFromDescription(description string, argumentList... interface{}) string {
	message := messageDetail[description]
	if message == "" {
		message = description
	}
	message = fmt.Sprintf(message, argumentList...)
	return message
}

func (self _error) MessageValue() Value {
	if self.Message == "" {
		return UndefinedValue()
	}
	return toValue(self.Message)
}

func (self _error) String() string {
	if len(self.Name) == 0 {
		return self.Message
	}
	if len(self.Message) == 0 {
		return self.Name
	}
	return fmt.Sprintf("%s: %s", self.Name, self.Message)
}

func newError(name string, argumentList... interface{}) _error {
	description := ""
	if len(argumentList) > 0 {
		description, argumentList = argumentList[0].(string), argumentList[1:]
	}
	return _error{
		Name: name,
		Message: messageFromDescription(description, argumentList...),
	}
}

func newReferenceError(argumentList... interface{}) _error {
	return newError("ReferenceError", argumentList...)
}

func newTypeError(argumentList... interface{}) _error {
	return newError("TypeError", argumentList...)
}

func newRangeError(argumentList... interface{}) _error {
	return newError("RangeError", argumentList...)
}

func newSyntaxError(argumentList... interface{}) _error {
	return newError("URIError", argumentList...)
}

func newURIError(argumentList... interface{}) _error {
	return newError("URIError", argumentList...)
}

func typeErrorResult(throw bool) bool {
	if throw {
		panic(newTypeError())
	}
	return false
}

func catchPanic(function func()) (err error) {
	defer func(){
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case _syntaxError:
				err = errors.New(caught.String())
				return
			case _error:
				err = errors.New(caught.String())
				return
			case _result:
				if caught.Kind == resultThrow {
					err = errors.New(toString(caught.Value))
				} else {
					// TODO Report this better
					err = errors.New("Here be dragons!")
				}
				return
			}
			panic(caught)
		}
	}()
	function()
	return nil
}

// SyntaxError

type _syntaxError struct {
	Message string
	Line int
	Column int
	Character int
}

func (self _syntaxError) String() string {
	name := "SyntaxError"
	if len(self.Message) == 0 {
		return name
	}
	return fmt.Sprintf("%s: %s", name, self.Message)
}

func (self _token) newSyntaxError(description string, argumentList... interface{}) *_syntaxError {
	return &_syntaxError{
		Message: messageFromDescription(description, argumentList...),
		Line: self.Line,
		Column: self.Column,
		Character: self.Character,
	}
}
