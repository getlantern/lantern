package otto

import (
	"fmt"
	"strings"
	"bytes"
	"unicode"
	"unicode/utf8"
	"unicode/utf16"
	"strconv"
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
`)

var punctuatorTable map[string]bool
func init() {

	punctuatorTable = boolFields(`
		>>>= === !== >>> <<= >>=
	`)

	// 2-character
	// <= >= == != ++ -- << >> && ||
	// += -= *= %= &= |= ^= /=
	for _, value := range "<>=!+-*%&|^/" {
		punctuatorTable[string(value) + "="] = true
	}

	for _, value := range "+-<>&|" {
		punctuatorTable[string(value) + string(value)] = true
	}

	// 1-character
	for _, value := range "[]<>+-*%&|^!~?:=/;{},()" {
		punctuatorTable[string(value)] = true
	}
}

type _token struct {
	Line, Column, Character int
	Kind, File, Text string
	Error bool
}

func (self _token) IsValid() bool {
	return self.Kind != ""
}

type _lexer struct {
	Source		string
	Tail		int
	Head		int
	Width		int

	Line int
	LineHead int
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
		self.Next()
	}
	if chr == '\r' && self.Next() != '\n' {
		self.Back() // Back because the next character was NOT \n
	}
	self.Line += 1
	return true
}

func (self *_lexer) ScanLineComment() {
	for {
		chr := self.Next()
		if chr == endOfFile || self.scanEndOfLine(chr, false) {
			return
		}
	}
}

func (self *_lexer) ScanBlockComment() int {
	lineCount := 0
	for {
		chr := self.Next()
		switch {
		case chr == '*' && self.Peek() == '/':
			self.Next() // /
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
		chr := self.Peek()
		switch {
		case chr == '/':
			read, _, _ := self.Read(3)
			switch read[1] {
			case '/':
				self.ScanLineComment()
				lineCount += 1
			case '*':
				lineCount += self.ScanBlockComment()
			default:
				goto RETURN
			}
			self.Ignore()
			self.LineHead = self.Tail
		case isWhiteSpace(chr):
			self.Next()
			self.Ignore()
		case self.scanEndOfLine(chr, true):
			lineCount += 1
			self.Ignore()
			self.LineHead = self.Tail
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

	if self.Peek() == endOfFile {
		return self.Emit("EOF")
	}

	if token = self.scanPunctuator(); token.IsValid() {
		return
	}

	rune := self.Peek()

	if rune == '\'' || rune == '"' {
		if token = self.scanQuoteLiteral(); token.IsValid() {
			return
		}
	}

	if rune == '.' || isDecimalDigit(rune) {
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

	value := self.Next()
	quote := value
	kind := "string"
	if value == '/' {
		kind = "//"
	}

	error := func() _token {
		if self.Width != 0 {
			self.Back()
		}
		return self.Emit("illegal")
	}

	var text bytes.Buffer

	for {
		value = self.Next()
		switch value {
		case endOfFile:
			return error()
		case quote:
			return self.EmitWith(kind, text.String())
		case '\\':
			value = self.Next()
			if isLineTerminator(value) {
				if quote == '/' {
					return error()
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
				text.WriteRune('\t')
			case 't':
				text.WriteRune('\t')
			case 'b':
				text.WriteRune('\t')
			case 'f':
				text.WriteRune('\t')
			case 'v':
				text.WriteRune('\t')
			default:
				text.WriteRune(value)
			case 'u':
				result := self.scanHexadecimalRune(4)
				if result != utf8.RuneError {
					text.WriteRune(result)
				} else {
					text.WriteRune(value)
				}

			case 'x':
				result := self.scanHexadecimalRune(2)
				if result != utf8.RuneError {
					text.WriteRune(result)
				} else {
					text.WriteRune(value)
				}
			}
			// TODO Octal escaping
		default:
			if isLineTerminator(value) {
				return error()
			}
			text.WriteRune(value)
		}
	}

	return error()
}

func (self *_lexer) scanHexadecimalRune(size int) rune {
	_, read, width := self.Read(size)
	value, err := strconv.ParseUint(read, 16, size * 4)
	if err != nil {
		// Not a valid hexadecimal sequence
		return utf8.RuneError
	}
	self.Tail += width
	return utf16.Decode([]uint16{uint16(value)})[0]
}

func (self *_lexer) scanPunctuator() (token _token) {

	if self.Accept(";{},()") {
		return self.Emit("punctuator")
	}

	accept := func(count int){
		for count > 0 {
			count--
			self.Next()
		}
	}

	read, word, _ := self.Read(4)

	if read[0] == '.' && !isDecimalDigit(read[1]) {
		accept(1)
		return self.Emit("punctuator")
	}

	for len(word) > 0 {
		if punctuatorTable[word] {
			accept(len(word))
			return self.Emit("punctuator")
		}
		word = word[:len(word) - 1]
	}

	return self.Emit("punctuator")
}

func (self *_lexer) scanNumericLiteral() _token {
	// FIXME Make sure this is according to the specification

	isHex, isOctal := false, false
	{
		self.Accept(".")

		acceptable := "0123456789"
		if self.Accept("0") {
			if self.Accept("xX") {
				acceptable = "0123456789abcdefABCDEF"
				isHex = true
			} else if self.Accept("01234567") {
				acceptable = "01234567"
				isOctal = true
			} else if self.Accept("89") {
				return self.Emit("illegal")
			}
		}

		self.AcceptRun(acceptable)
		if !isHex && !isOctal && self.Accept(".") {
			self.AcceptRun(acceptable)
		}

		if self.Length() == 2 && isHex { // 0x$ or 0X$
			return self.Emit("illegal")
		}
	}

	if !isHex && !isOctal && self.Accept("eE") {
		self.Accept("+-")
		length := self.Length()
		self.AcceptRun("0123456789")
		if length == self.Length() { // <number>e$
			return self.Emit("illegal")
		}
	}

	if isAlphaNumeric(self.Peek()) {
		self.Next()
		// Bad number
		return self.Emit("illegal")
	}

	return self.Emit("number")
}

func (self *_lexer) scanIdentifierKeyword() (token _token) {
	if !isIdentifierStart(self.Peek()) {
		return
	}
	for {
		switch chr := self.Peek(); {
		case isAlphaNumericDollar(chr):
			self.Next()
		default:
			word := self.Word()
			switch {
			case keywordTable[word] == true:
				return self.Emit(word)
			case word == "true", word == "false":
				return self.Emit("boolean")
			default:
				return self.Emit("identifier")
			}
			return
		}
	}
	return
}

func (self *_lexer) scanIllegal() _token {
	return self.Emit("illegal")
}

func (self *_lexer) EmitWith(kind string, text string) _token {
	token := _token{
		Character: 1 + self.Head,
		Line: 1 + self.Line,
		Column: 1 + self.Head - self.LineHead,

		Kind: kind,
		Text: text,
		Error: false,
	}
	if kind == "punctuator" {
		token.Kind = token.Text
	}
	self.Head = self.Tail
	if ottoDebug {
		fmt.Printf("emit: %s %s\n", token.Kind, token.Text)
	}
	if kind == "illegal" {
		token.Error = true
	}
	return token
}

func (self *_lexer) Emit(kind string) _token {
	return self.EmitWith(kind, self.Word())
}

func (self *_lexer) Read(count int) ([]rune, string, int) {
	read := make([]rune, count)
	tail := self.Tail
	found := 0
	for i := 0; i < count; i++ {
		if tail >= len(self.Source) {
			read[i] = endOfFile
			continue
		}
		width := 0
		read[i], width = utf8.DecodeRuneInString(self.Source[tail:])
		tail += width
		found = i
	}
	distance := tail - self.Tail
	word := string(read[:found + 1])
	return read, word, distance
}

func (self *_lexer) Next() (chr rune) {
	chr, self.Width = self._Peek()
	self.Tail += self.Width
	return chr
}

func (self *_lexer) _Peek() (rune, int) {
	if self.Tail >= len(self.Source) {
		return endOfFile, 0
	}
	chr, width := utf8.DecodeRuneInString(self.Source[self.Tail:])
	return chr, width
}

func (self *_lexer) Peek() rune {
	chr, _ := self._Peek()
	return chr
}

func (self *_lexer) Back() {
	if self.Width == 0 {
		panic(hereBeDragons("Can't backup when self.Width == 0"))
	}
	self.Tail -= self.Width
}

func (self *_lexer) Ignore() {
	self.Head = self.Tail
}

func (self *_lexer) Accept(valid string) bool {
	if strings.IndexRune(valid, self.Peek()) >= 0 {
		self.Next()
		return true
	}
	return false
}

func (self *_lexer) AcceptRun(valid string) bool {
	found := false
	for strings.IndexRune(valid, self.Peek()) >= 0 {
		self.Next()
		found = true
	}
	return found
}

func (self *_lexer) Word() string {
	return self.Source[self.Head:self.Tail]
}

func (self *_lexer) Length() int {
	return self.Tail - self.Head
}

func isDecimalDigit(rune rune) bool {
	return unicode.IsDigit(rune)
}

func isAlphaNumeric(rune rune) bool {
	return rune == '_' || unicode.IsLetter(rune) || unicode.IsDigit(rune)
}

func isAlphaNumericDollar(rune rune) bool {
	return rune == '$' || rune == '_' || unicode.IsLetter(rune) || unicode.IsDigit(rune)
}

func isIdentifierStart(rune rune) bool {
	return rune == '$' || rune == '_' || unicode.IsLetter(rune)
}

func isWhiteSpace(chr rune) bool {
	switch chr {
	case ' ', '\t':
		return true
	}
	return false
}

func isLineTerminator(chr rune) bool {
	switch chr {
	case '\n', '\r', '\u2028', '\u2029':
		return true
	}
	return false
}
