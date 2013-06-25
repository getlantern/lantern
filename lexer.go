package otto

import (
	"bytes"
	"fmt"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf16"
	"unicode/utf8"
)

var keywordTable map[string]bool = boolFields(`
	break
	case
	catch
	continue
	default
	delete
	do
	else
	finally
	for
	function
	if
	in
	instanceof
	new
	null
	return
	switch
	this
	throw
	try
	typeof
	var
	while
	with
	void

	debugger
	const
`)

var futureKeywordTable map[string]bool = boolFields(`
    class
    enum
    export
    extends
    import
    super
`)

func init() {
	for keyword, _ := range futureKeywordTable {
		keywordTable[keyword] = true
	}
}

var punctuatorTable map[string]bool

func init() {

	punctuatorTable = boolFields(`
		>>>= === !== >>> <<= >>=
	`)

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

type _token struct {
	Line, Column, Character int
	Kind, File, Text        string
	Error                   bool
}

func (self _token) IsValid() bool {
	return self.Kind != ""
}

type _lexer struct {
	Source string
	//Tail		int
	//Head		int
	//Width		int

	lineCount        int
	zeroColumnOffset int

	readIn       []rune
	readInOffset int
	atEndOfFile  bool
	head         int
	tail         int

	headOffset int
	tailOffset int
}

// Only called for testing (for now)
func newLexer(source string) _lexer {
	self := _lexer{
		Source: source,
		readIn: make([]rune, 0, len(source)), // Guestimate
	}
	return self
}

func (self _lexer) Copy() *_lexer {
	newSelf := self
	return &newSelf
}

func (self *_lexer) scanEndOfLine(chr rune, consume bool) bool {
	if !isLineTerminator(chr) {
		return false
	}
	if consume {
		self.next()
	}
	if chr == '\r' && self.peek() == '\n' {
		self.next() // Consume \n
	}
	self.lineCount += 1
	return true
}

func (self *_lexer) ScanLineComment() {
	for {
		chr := self.next()
		if chr == endOfFile || self.scanEndOfLine(chr, false) {
			return
		}
	}
}

func (self *_lexer) ScanBlockComment() int {
	lineCount := 0
	for {
		chr := self.next()
		switch {
		case chr == '*' && self.peek() == '/':
			self.next() // /
			return lineCount
		case chr == endOfFile:
			panic(&_syntaxError{
				Message: "Unexpected token ILLEGAL",
			})
		case self.scanEndOfLine(chr, false):
			lineCount += 1
		}
	}
	panic(hereBeDragons())
}

func (self *_lexer) ScanSkip() int {

	lineCount := 0

	for {
		chr := self.peek()
		switch {
		case chr == '/':
			read, _, found, width := self.read(2)
			switch read[1] {
			case '/':
				self.tail += found
				self.tailOffset += width
				self.ScanLineComment()
				lineCount += 1
			case '*':
				self.tail += found
				self.tailOffset += width
				lineCount += self.ScanBlockComment()
			default:
				goto RETURN
			}
			self.ignore()
			self.zeroColumnOffset = self.tailOffset
		case isWhiteSpace(chr):
			self.next()
			self.ignore()
		case self.scanEndOfLine(chr, true):
			lineCount += 1
			self.ignore()
			self.zeroColumnOffset = self.tailOffset
		default:
			goto RETURN
		}
	}

RETURN:
	return lineCount
}

func (self *_lexer) ScanLineSkip() bool {
	return self.ScanSkip() > 0
}

func (self *_lexer) ScanRegularExpression() _token {

	self.ScanSkip()

	token := self.scanQuoteLiteral()
	if token.Kind != "//" {
		panic(token.newSyntaxError("Invalid regular expression"))
	}
	return token
}

func (self *_lexer) Scan() (token _token) {

	self.ScanSkip()

	if self.peek() == endOfFile {
		return self.emit("EOF")
	}

	if token = self.scanPunctuator(); token.IsValid() {
		return
	}

	chr := self.peek()

	if chr == '\'' || chr == '"' {
		if token = self.scanQuoteLiteral(); token.IsValid() {
			return
		}
	}

	if chr == '.' || isDecimalDigit(chr) {
		if token = self.scanNumericLiteral(); token.IsValid() {
			return
		}
	}

	if token = self.scanIdentifierKeyword(); token.IsValid() {
		return
	}

	return self.scanIllegal()
}

func (self *_lexer) scanQuoteLiteral() _token {

	value := self.next()
	quote := value
	kind := "string"
	if value == '/' {
		kind = "//"
	}

	errorIllegal := func() _token {
		self.back()
		return self.emit("illegal")
	}

	var text bytes.Buffer

	for {
		value = self.next()
		switch value {
		case endOfFile:
			return errorIllegal()
		case quote:
			return self.emitWith(kind, text.String())
		case '\\':
			value = self.next()
			if isLineTerminator(value) {
				if quote == '/' {
					return errorIllegal()
				}
				self.scanEndOfLine(value, false)
				continue
			}
			if quote == '/' { // RegularExpression
				// TODO Handle the case of [\]?
				text.WriteRune('\\')
				text.WriteRune(value)
				continue
			}
			switch value {
			case 'n':
				text.WriteRune('\n')
			case 'r':
				text.WriteRune('\r')
			case 't':
				text.WriteRune('\t')
			case 'b':
				text.WriteRune('\b')
			case 'f':
				text.WriteRune('\f')
			case 'v':
				text.WriteRune('\v')
			case '0':
				text.WriteRune(0)
			case 'u':
				result := self.scanHexadecimalRune(4)
				if result != utf8.RuneError {
					text.WriteRune(result)
				} else {
					return errorIllegal()
				}

			case 'x':
				result := self.scanHexadecimalRune(2)
				if result != utf8.RuneError {
					text.WriteRune(result)
				} else {
					return errorIllegal()
				}
			default:
				text.WriteRune(value)
			}
			// TODO Octal escaping
		default:
			if isLineTerminator(value) {
				return errorIllegal()
			}
			text.WriteRune(value)
		}
	}

	return self.emit("illegal")
}

func convertHexadecimalRune(word string) rune {
	value, err := strconv.ParseUint(word, 16, len(word)*4)
	if err != nil {
		// Not a valid hexadecimal sequence
		return utf8.RuneError
	}
	return utf16.Decode([]uint16{uint16(value)})[0]
}

func (self *_lexer) scanHexadecimalRune(size int) rune {
	_, word, found, width := self.read(size)
	chr := convertHexadecimalRune(word)
	if chr == utf8.RuneError {
		return chr
	}
	self.tail += found
	self.tailOffset += width
	return chr
}

func (self *_lexer) scanPunctuator() (token _token) {

	if self.accept(";{},()") {
		return self.emit("punctuator")
	}

	accept := func(count int) {
		for count > 0 {
			count--
			self.next()
		}
	}

	read, word, _, _ := self.read(4)

	if read[0] == '.' && !isDecimalDigit(read[1]) {
		accept(1)
		return self.emit("punctuator")
	}

	for len(word) > 0 {
		if punctuatorTable[word] {
			accept(len(word))
			return self.emit("punctuator")
		}
		word = word[:len(word)-1]
	}

	return
	// I think this doesn't make any sense
	//return self.emit("punctuator")
}

func (self *_lexer) scanNumericLiteral() _token {
	// FIXME Make sure this is according to the specification

	isHex, isOctal := false, false
	{
		acceptable := "0123456789"
		if !self.accept(".") && self.accept("0") {
			if self.accept("xX") {
				acceptable = "0123456789abcdefABCDEF"
				isHex = true
			} else if self.accept("01234567") {
				acceptable = "01234567"
				isOctal = true
			} else if self.accept("89") {
				return self.emit("illegal")
			}
		}

		self.acceptRun(acceptable)
		if !isHex && !isOctal && self.accept(".") {
			self.acceptRun(acceptable)
		}

		if self.length() == 2 && isHex { // 0x$ or 0X$
			return self.emit("illegal")
		}
	}

	if !isHex && !isOctal && self.accept("eE") {
		self.accept("+-")
		length := self.length()
		self.acceptRun("0123456789")
		if length == self.length() { // <number>e$
			return self.emit("illegal")
		}
	}

	if isAlphaNumeric(self.peek()) {
		self.next()
		// Bad number
		return self.emit("illegal")
	}

	return self.emit("number")
}

func (self *_lexer) scanIdentifierKeyword() (token _token) {
	word := []rune{}

	// The first character should be of the class isIdentifierStart
	identifierCheck := isIdentifierStart

	for {
		switch chr := self.peek(); {
		case identifierCheck(chr):
			if chr == '\\' {
				read, _, _, _ := self.read(6)
				if read[1] == 'u' {
					chr := convertHexadecimalRune(string(read[2:]))
					if chr == utf8.RuneError {
						word = append(word, 'u')
						self.skip(2) // Skip \u
					} else {
						if chr == '\\' || !identifierCheck(chr) {
							return
						}
						word = append(word, chr)
						self.skip(6) // Skip \u????
					}
				} else {
					return
				}
			} else {
				// Basically a skip of 1
				word = append(word, self.next())
			}
		default:
			if len(word) == 0 {
				// Did not scan at least one identifier character, so return with failure
				return
			}
			word := string(word)
			switch {
			case keywordTable[word] == true:
				return self.emitWith(word, word)
			case word == "true", word == "false":
				return self.emitWith("boolean", word)
			default:
				return self.emitWith("identifier", word)
			}
			return
		}

		// Now we're looking at the body of the identiifer
		identifierCheck = isIdentifierPart
	}

	return
}

func (self *_lexer) scanIllegal() _token {
	return self.emit("illegal")
}

func (self *_lexer) emitWith(kind string, text string) _token {
	token := _token{
		Character: 1 + self.tailOffset,
		Line:      1 + self.lineCount,
		Column:    1 + self.tailOffset - self.zeroColumnOffset,

		Kind:  kind,
		Text:  text,
		Error: false,
	}
	if kind == "punctuator" {
		token.Kind = token.Text
	}

	self.headOffset = self.tailOffset
	self.head = self.tail

	if ottoDebug {
		fmt.Printf("emit: %s %s\n", token.Kind, token.Text)
	}
	if kind == "illegal" {
		token.Error = true
	}
	return token
}

func (self *_lexer) emit(kind string) _token {
	return self.emitWith(kind, self.word())
}

func (self *_lexer) read(count int) ([]rune, string, int, int) {
	head := self.tail
	tail := head + count
	unread := tail - len(self.readIn)
	for unread > 0 {
		unread--
		self.read1()
	}

	var read []rune
	found := 0
	length := len(self.readIn)
	if tail >= length {
		read = make([]rune, count)
		index, head := 0, head
		for index < count {
			if head >= length {
				read[index] = endOfFile
			} else {
				found++
				read[index] = self.readIn[head]
			}
			index++
			head++
		}
	} else {
		found = count
		read = self.readIn[head:tail]
	}

	width := 0
	word := ""
	if found > 0 {
		width = len(string(read[:found]))
		word = string(read[:found])
	}

	return read, word, found, width
}

func (self *_lexer) next() rune {
	chr, width := self.peek1()
	if width != 0 {
		self.tail += 1
		self.tailOffset += width
	}
	return chr
}

func (self *_lexer) skip(count int) {
	read := self.readIn[self.tail : self.tail+count]
	for _, chr := range read {
		self.tail += 1
		self.tailOffset += utf8.RuneLen(chr)
	}
}

func (self *_lexer) peek1() (chr rune, width int) {
	if self.tail < len(self.readIn) {
		chr = self.readIn[self.tail]
		width = utf8.RuneLen(chr)
	} else {
		chr, width = self.read1()
	}
	return
}

func (self *_lexer) read1() (rune, int) {
	if self.readInOffset >= len(self.Source) {
		self.atEndOfFile = true
		return endOfFile, 0
	}
	chr, width := utf8.DecodeRuneInString(self.Source[self.readInOffset:])
	self.readIn = append(self.readIn, chr)
	self.readInOffset += width
	return chr, width
}

func (self *_lexer) peek() rune {
	chr, _ := self.peek1()
	return chr
}

func (self *_lexer) back() {
	if self.tail > self.head && self.tail > 0 {
		self.tailOffset -= utf8.RuneLen(self.readIn[self.tail-1])
		self.tail -= 1
	}
}

func (self *_lexer) ignore() {
	self.head = self.tail
	self.headOffset = self.tailOffset
}

func (self *_lexer) accept(valid string) bool {
	if strings.IndexRune(valid, self.peek()) >= 0 {
		self.next()
		return true
	}
	return false
}

func (self *_lexer) acceptRun(valid string) bool {
	found := false
	for strings.IndexRune(valid, self.peek()) >= 0 {
		self.next()
		found = true
	}
	return found
}

func (self *_lexer) word() string {
	return self.Source[self.headOffset:self.tailOffset]
}

func (self *_lexer) length() int {
	return self.tailOffset - self.headOffset
}

func isDecimalDigit(rune rune) bool {
	return unicode.IsDigit(rune)
}

func isAlphaNumeric(chr rune) bool {
	return chr == '_' || unicode.IsLetter(chr) || unicode.IsDigit(chr)
}

func isIdentifierStart(chr rune) bool {
	return chr == '$' || chr == '_' || chr == '\\' || unicode.IsLetter(chr)
}

func isIdentifierPart(chr rune) bool {
	return chr == '$' || chr == '_' || chr == '\\' || unicode.IsLetter(chr) || unicode.IsDigit(chr)
}

func isWhiteSpace(chr rune) bool {
	switch chr {
	case '\u0009', '\u000b', '\u000c', '\u0020', '\u00a0', '\ufeff':
		return true
	case '\u000a', '\u000d', '\u2028', '\u2029':
		return false
	case '\u0085':
		return false
	}
	return unicode.IsSpace(chr)
}

func isLineTerminator(chr rune) bool {
	switch chr {
	case '\u000a', '\u000d', '\u2028', '\u2029':
		return true
	}
	return false
}

func isWhiteSpaceOrLineTerminator(chr rune) bool {
	switch chr {
	case '\u0009', '\u000b', '\u000c', '\u0020', '\u00a0', '\ufeff':
		return true
	case '\u000a', '\u000d', '\u2028', '\u2029':
		return true
	case '\u0085':
		return false
	}
	return unicode.IsSpace(chr)
}
