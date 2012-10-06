package otto

import (
)

type _resultKind int

const (
	resultNormal _resultKind = iota
	resultReturn
	resultThrow
	resultBreak
	resultContinue
)

type _result struct {
	Kind _resultKind
	Value Value
	Target string
}

func newReturnResult(value Value) _result {
	return _result{resultReturn, value, ""}
}

func newContinueResult(target string) _result {
	return _result{resultContinue, emptyValue(), target}
}

func newBreakResult(target string) _result {
	return _result{resultBreak, emptyValue(), target}
}

func newThrowResult(value Value) _result {
	return _result{resultThrow, value, ""}
}
