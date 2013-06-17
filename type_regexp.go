package otto

import (
	"bytes"
	"fmt"
	"regexp"
	"strings"
	"unicode/utf8"
)

type _regExpObject struct {
	regularExpression *regexp.Regexp
	global            bool
	ignoreCase        bool
	multiline         bool
	source            string
	flags             string
}

func (runtime *_runtime) newRegExpObject(pattern string, flags string) *_object {
	self := runtime.newObject()
	self.class = "RegExp"

	global := false
	ignoreCase := false
	multiline := false
	re2flags := ""

	for _, chr := range flags {
		switch chr {
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
			re2flags += "m"
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

	regularExpression, err := regexp.Compile(re2pattern)
	if err != nil {
		panic(newSyntaxError("Invalid regular expression: %s", err.Error()[22:]))
	}

	self.value = _regExpObject{
		regularExpression: regularExpression,
		global:            global,
		ignoreCase:        ignoreCase,
		multiline:         multiline,
		source:            pattern,
		flags:             flags,
	}
	self.defineProperty("global", toValue_bool(global), 0, false)
	self.defineProperty("ignoreCase", toValue_bool(ignoreCase), 0, false)
	self.defineProperty("multiline", toValue_bool(multiline), 0, false)
	self.defineProperty("lastIndex", toValue_int(0), 0100, false)
	self.defineProperty("source", toValue_string(pattern), 0, false)
	return self
}

func (self *_object) regExpValue() _regExpObject {
	value, _ := self.value.(_regExpObject)
	return value
}

func execRegExp(this *_object, target string) (match bool, result []int) {
	if this.class != "RegExp" {
		panic(newTypeError("Calling RegExp.exec on a non-RegExp object"))
	}
	lastIndex := toInteger(this.get("lastIndex")).value
	index := lastIndex
	global := toBoolean(this.get("global"))
	if !global {
		index = 0
	}
	if 0 > index || index > int64(len(target)) {
	} else {
		result = this.regExpValue().regularExpression.FindStringSubmatchIndex(target[index:])
	}
	if result == nil {
		//this.defineProperty("lastIndex", toValue_(0), 0111, true)
		this.put("lastIndex", toValue_int(0), true)
		return // !match
	}
	match = true
	startIndex := index
	endIndex := int(lastIndex) + result[1]
	// We do this shift here because the .FindStringSubmatchIndex above
	// was done on a local subordinate slice of the string, not the whole string
	for index, _ := range result {
		result[index] += int(startIndex)
	}
	if global {
		//this.defineProperty("lastIndex", toValue_(endIndex), 0111, true)
		this.put("lastIndex", toValue_int(endIndex), true)
	}
	return // match
}

func execResultToArray(runtime *_runtime, target string, result []int) *_object {
	captureCount := len(result) / 2
	valueArray := make([]Value, captureCount)
	for index := 0; index < captureCount; index++ {
		offset := 2 * index
		if result[offset] != -1 {
			valueArray[index] = toValue_string(target[result[offset]:result[offset+1]])
		} else {
			valueArray[index] = UndefinedValue()
		}
	}
	matchIndex := result[0]
	if matchIndex != 0 {
		matchIndex = 0
		// Find the rune index in the string, not the byte index
		for index := 0; index < result[0]; {
			_, size := utf8.DecodeRuneInString(target[index:])
			matchIndex += 1
			index += size
		}
	}
	match := runtime.newArrayOf(valueArray)
	match.defineProperty("input", toValue_string(target), 0111, false)
	match.defineProperty("index", toValue_int(matchIndex), 0111, false)
	return match
}

// 0031,0032,0033,0034,0035,0036,0037,0038,0039 // 1 - 9
// 0043,0045,0046,0047,0048,0049,004A,004B,004C,004D,004E,004F
// 0050,0052,0054,0055,0056,0058,0059,005A
// 0063,0065,0067,0068,0069,006A,006B,006C,006D,006F
// 0070,0071,0075,0078,0079
// 0080,0081,0082,0083,0084,0085,0086,0087,0088,0089,008A,008B,008C,008D,008E,008F
// 0090,0091,0092,0093,0094,0095,0096,0097,0098,0099,009A,009B,009C,009D,009E,009F
// 00A0,00A1,00A2,00A3,00A4,00A5,00A6,00A7,00A8,00A9,00AA,00AB,00AC,00AD,00AE,00AF
// 00B0,00B1,00B2,00B3,00B4,00B5,00B6,00B7,00B8,00B9,00BA,00BB,00BC,00BD,00BE,00BF
// 00C0,00C1,00C2,00C3,00C4,00C5,00C6,00C7,00C8,00C9,00CA,00CB,00CC,00CD,00CE,00CF
// ...
// c = 63* c[A-Z]
// p = 70
// u = 75* u[:xdigit:]{4}
// x = 78* x[:xdigit:]{2}
//\x{0031}-\x{0039}

var transformRegExp_matchSlashU = regexp.MustCompile(`\\u([[:xdigit:]]{1,4})`)
var transformRegExp_escape_c = regexp.MustCompile(`\\c([A-Za-z])`)
var transformRegExp_unescape_c = regexp.MustCompile(`\\c`)
var transformRegExp_unescape = []*regexp.Regexp{
	regexp.MustCompile(strings.NewReplacer("\n", "", "\t", "", " ", "").Replace(`
		\\(
		[
			\x{0043}\x{0045}-\x{004F}
			\x{0050}\x{0052}\x{0054}-\x{0056}\x{0058}-\x{005A}
			\x{0065}\x{0067}-\x{006D}\x{006F}
			\x{0070}\x{0071}\x{0079}
			\x{0080}-\x{FFFF}
		]
		)()
	`)),
	regexp.MustCompile(`\\(u)([^[:xdigit:]])`),
	regexp.MustCompile(`\\(u)([[:xdigit:]][^[:xdigit:]])`),
	regexp.MustCompile(`\\(u)([[:xdigit:]][[:xdigit:]][^[:xdigit:]])`),
	regexp.MustCompile(`\\(u)([[:xdigit:]][[:xdigit:]][[:xdigit:]][^[:xdigit:]])`),
	regexp.MustCompile(`\\(x)([^[:xdigit:]])`),
	regexp.MustCompile(`\\(x)([[:xdigit:]][^[:xdigit:]])`),
}

var transformRegExp_unescapeDollar = regexp.MustCompile(`\\([cux])$`)

// TODO Go "regexp" bug? Can't do: (?:)|(?:$)

func transformRegExp(ecmaRegExp string) (goRegExp string) {
	// https://bugzilla.mozilla.org/show_bug.cgi/show_bug.cgi?id=334158
	tmp := []byte(ecmaRegExp)
	for _, value := range transformRegExp_unescape {
		tmp = value.ReplaceAll(tmp, []byte(`$1$2`))
	}
	tmp = transformRegExp_escape_c.ReplaceAllFunc(tmp, func(in []byte) []byte {
		in = bytes.ToUpper(in)
		// in = [ \, c, A-Z ]
		in[2] -= 64 // 64 => 01
		return []byte(fmt.Sprintf("\\0%o", in[2]))
	})
	tmp = transformRegExp_unescape_c.ReplaceAll(tmp, []byte(`c`))
	tmp = transformRegExp_unescapeDollar.ReplaceAll(tmp, []byte(`$1`))
	tmp = transformRegExp_matchSlashU.ReplaceAll(tmp, []byte(`\x{$1}`))
	return string(tmp)
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
