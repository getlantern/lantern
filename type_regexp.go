package otto

import (
	"fmt"
	"regexp"
)

type _regExpObject struct {
	RegularExpression *regexp.Regexp
	Global bool
	IgnoreCase bool
	Multiline bool
	Source string
	LastIndex Value
}

func (runtime *_runtime) newRegExpObject(pattern string, flags string) *_object {
	self := runtime.newObject()
	self.Class = "RegExp"

	global := false
	ignoreCase := false
	multiline := false
	re2flags := ""

	for _, rune := range flags {
		switch rune {
		case 'g':
			if global {
				panic(newError("SyntaxError: newRegExpObject: %s %s", pattern, flags))
			}
			global = true
		case 'm':
			if multiline {
				panic(newError("SyntaxError: newRegExpObject: %s %s", pattern, flags))
			}
			multiline = true
		case 'i':
			if ignoreCase {
				panic(newError("SyntaxError: newRegExpObject: %s %s", pattern, flags))
			}
			ignoreCase = true
			re2flags += "i"
		}
	}

	re2pattern := transformRegExp(pattern)
	if len(re2flags) > 0 {
		re2pattern = fmt.Sprintf("(?%s:%s)", re2flags, re2pattern)
	}

	self.RegExp = &_regExpObject{
		RegularExpression: regexp.MustCompile(re2pattern),
		Global: global,
		IgnoreCase: ignoreCase,
		Multiline: multiline,
		Source: pattern,
		LastIndex: toValue(0),
	}
	self._propertyStash = newRegExpStash(self.RegExp, self._propertyStash)
	return self
}

func execRegExp(this *_object, target string) (match bool, result []int) {
	lastIndex := toInteger(this.Get("lastIndex"))
	index := lastIndex
	global := toBoolean(this.Get("global"))
	if !global {
		index = 0
	}
	if 0 > index || index > int64(len(target)) {
	} else {
		result = this.RegExp.RegularExpression.FindStringSubmatchIndex(target[index:])
	}
	if result == nil {
		this.WriteValue("lastIndex", toValue(0), true)
		return // !match
	}
	match = true
	endIndex := result[len(result)-1]
	if global {
		this.WriteValue("lastIndex", toValue(endIndex), true)
	}
	return // match
}

func execResultToArray(runtime *_runtime, target string, result []int) *_object {
	captureCount := len(result) / 2
	valueArray := make([]Value, captureCount)
	for index := 0; index < captureCount; index++ {
		offset := 2 * index
		if result[offset] != -1 {
			valueArray[index] = toValue(target[result[offset]:result[offset+1]])
		} else {
			valueArray[index] = UndefinedValue()
		}
	}
	return runtime.newArray(valueArray)
}

/*var transformRegExp_matchSlashU *regexp.Regexp = regexp.MustCompile(`\\u([:xdigit:]{1-4})`)*/
var transformRegExp_matchSlashU *regexp.Regexp = regexp.MustCompile(`\\u([[:xdigit:]]{1,4})`)

func transformRegExp(ecmaRegExp string) (goRegExp string) {
	return transformRegExp_matchSlashU.ReplaceAllString(ecmaRegExp, `\x{$1}`)
}

func isValidRegExp(ecmaRegExp string) bool {
	shibboleth := 0 // The shibboleth in this case is (?
					// Since we're looking for (?! / (?=
	inSet := false // In a bracketed set, e.g. [0-9]
	escape := false
	for _, chr := range ecmaRegExp {
		if escape {
			escape = false
			shibboleth = 0
			continue
		}
		if chr == '\\' {
			escape = true
			continue
		}
		if inSet {
			if chr == ']' {
				inSet = false
				shibboleth = 0
			}
			continue
		}
		switch chr {
		case '[':
			inSet = true
			continue
		case '(':
			shibboleth = 1
			continue
		case '?':
			if shibboleth == 1 {
				shibboleth = 2
			}
			continue
		case '=', '!':
			if shibboleth == 2 {
				return false
			}
		}
		shibboleth = 0
	}

	return true
}

// _regExpStash

type _regExpStash struct {
	_regExpObject *_regExpObject
	_stash
}

func newRegExpStash(_regExpObject *_regExpObject, stash _stash) *_regExpStash {
	self := &_regExpStash{
		_regExpObject,
		stash,
	}
	return self
}

func (self *_regExpStash) CanRead(name string) bool {
	switch name {
	case "global", "ignoreCase", "multiline", "lastIndex", "source":
		return true
	}
	return self._stash.CanRead(name)
}

func (self *_regExpStash) Read(name string) Value {
	switch name {
	case "global":
		return toValue(self._regExpObject.Global)
	case "ignoreCase":
		return toValue(self._regExpObject.IgnoreCase)
	case "multiline":
		return toValue(self._regExpObject.Multiline)
	case "lastIndex":
		return self._regExpObject.LastIndex
	case "source":
		return toValue(self._regExpObject.Source)
	}
	return self._stash.Read(name)
}

func (self *_regExpStash) Write(name string, value Value) {
	switch name {
	case "global", "ignoreCase", "multiline", "source":
		// TODO Is this good enough? Check DefineOwnProperty
		panic(newTypeError())
	case "lastIndex":
		self._regExpObject.LastIndex = value
		return
	}
	self._stash.Write(name, value)
}

func (self *_regExpStash) property(name string) *_property {
	switch name {
	case "global":
		return &_property{Value: toValue(self._regExpObject.Global), Mode: 0} // -Write -Enumerate -Configure
	case "ignoreCase":
		return &_property{Value: toValue(self._regExpObject.IgnoreCase), Mode: 0} // -Write -Enumerate -Configure
	case "multiline":
		return &_property{Value: toValue(self._regExpObject.Multiline), Mode: 0} // -Write -Enumerate -Configure
	case "lastIndex":
		return &_property{Value: (self._regExpObject.LastIndex), Mode: propertyModeWrite} // +Write -Enumerate -Configure
	case "source":
		return &_property{Value: toValue(self._regExpObject.Source), Mode: 0} // -Write -Enumerate -Configure
	}
	return self._stash.property(name)
}

func (self *_regExpStash) Enumerate(each func(string)) {
	// Skip global, ignoreCase, multiline, source, & lastIndex
	self._stash.Enumerate(each)
}
