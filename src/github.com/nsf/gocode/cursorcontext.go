package main

import (
	"go/ast"
	"go/parser"
	"go/scanner"
	"go/token"
	"log"
)

type cursor_context struct {
	decl    *decl
	partial string
}

type token_iterator struct {
	tokens      []token_item
	token_index int
}

type token_item struct {
	off int
	tok token.Token
	lit string
}

func (i token_item) Literal() string {
	if i.tok.IsLiteral() {
		return i.lit
	} else {
		return i.tok.String()
	}
	return ""
}

func (this *token_iterator) token() token_item {
	return this.tokens[this.token_index]
}

func (this *token_iterator) previous_token() bool {
	if this.token_index <= 0 {
		return false
	}
	this.token_index--
	return true
}

var g_bracket_pairs = map[token.Token]token.Token{
	token.RPAREN: token.LPAREN,
	token.RBRACK: token.LBRACK,
}

// when the cursor is at the ')' or ']', move the cursor to an opposite bracket
// pair, this functions takes inner bracker pairs into account
func (this *token_iterator) skip_to_bracket_pair() bool {
	right := this.token().tok
	left := g_bracket_pairs[right]
	return this.skip_to_left_bracket(left, right)
}

func (this *token_iterator) skip_to_left_bracket(left, right token.Token) bool {
	// TODO: Make this functin recursive.
	if this.token().tok == left {
		return true
	}
	balance := 1
	for balance != 0 {
		this.previous_token()
		if this.token_index == 0 {
			return false
		}
		switch this.token().tok {
		case right:
			balance++
		case left:
			balance--
		}
	}
	return true
}

// Move the cursor to the open brace of the current block, taking inner blocks
// into account.
func (this *token_iterator) skip_to_open_brace() bool {
	return this.skip_to_left_bracket(token.LBRACE, token.RBRACE)
}

// try_extract_struct_init_expr tries to match the current cursor position as being inside a struct
// initialization expression of the form:
// &X{
// 	Xa: 1,
// 	Xb: 2,
// }
// Nested struct initialization expressions are handled correctly.
func (this *token_iterator) try_extract_struct_init_expr() []byte {
	for this.token_index >= 0 {
		if !this.skip_to_open_brace() {
			return nil
		}

		if !this.previous_token() {
			return nil
		}

		return []byte(this.token().Literal())
	}
	return nil
}

// starting from the end of the 'file', move backwards and return a slice of a
// valid Go expression
func (this *token_iterator) extract_go_expr() []byte {
	// TODO: Make this function recursive.
	orig := this.token_index

	// prev always contains the type of the previously scanned token (initialized with the token
	// right under the cursor). This is the token to the *right* of the current one.
	prev := this.token().tok
loop:
	for {
		this.previous_token()
		if this.token_index == 0 {
			return make_expr(this.tokens[:orig])
		}
		t := this.token().tok
		switch t {
		case token.PERIOD:
			if prev != token.IDENT {
				// Not ".ident".
				break loop
			}
		case token.IDENT:
			if prev == token.IDENT {
				// "ident ident".
				break loop
			}
		case token.RPAREN, token.RBRACK:
			if prev == token.IDENT {
				// ")ident" or "]ident".
				break loop
			}
			this.skip_to_bracket_pair()
		default:
			break loop
		}
		prev = t
	}
	exprT := this.tokens[this.token_index+1 : orig]
	if *g_debug {
		log.Printf("extracted expression tokens: %#v", exprT)
	}
	return make_expr(exprT)
}

// Given a slice of token_item, reassembles them into the original literal expression.
func make_expr(tokens []token_item) []byte {
	e := ""
	for _, t := range tokens {
		e += t.Literal()
	}
	return []byte(e)
}

// this function is called when the cursor is at the '.' and you need to get the
// declaration before that dot
func (c *auto_complete_context) deduce_cursor_decl(iter *token_iterator) *decl {
	e := string(iter.extract_go_expr())
	expr, err := parser.ParseExpr(e)
	if err != nil {
		return nil
	}
	return expr_to_decl(expr, c.current.scope)
}

func new_token_iterator(src []byte, cursor int) token_iterator {
	tokens := make([]token_item, 0, 1000)
	var s scanner.Scanner
	fset := token.NewFileSet()
	file := fset.AddFile("", fset.Base(), len(src))
	s.Init(file, src, nil, 0)
	token_index := 0
	for {
		pos, tok, lit := s.Scan()
		if tok == token.EOF {
			break
		}
		off := fset.Position(pos).Offset
		tokens = append(tokens, token_item{
			off: off,
			tok: tok,
			lit: lit,
		})
		if cursor > off {
			token_index++
		}
	}
	return token_iterator{
		tokens:      tokens,
		token_index: token_index,
	}
}

// deduce cursor context, it includes the declaration under the cursor and partial identifier
// (usually a part of the name of the child declaration)
func (c *auto_complete_context) deduce_cursor_context(file []byte, cursor int) (cursor_context, bool) {
	if cursor <= 0 {
		return cursor_context{nil, ""}, true
	}

	iter := new_token_iterator(file, cursor)
	if len(iter.tokens) == 0 {
		return cursor_context{nil, ""}, false
	}

	// figure out what is just before the cursor
	iter.previous_token()
	switch r := iter.token().tok; r {
	case token.PERIOD:
		// we're '<whatever>.'
		// figure out decl, Partial is ""
		decl := c.deduce_cursor_decl(&iter)
		return cursor_context{decl, ""}, decl != nil
	case token.IDENT, token.TYPE, token.CONST, token.VAR, token.FUNC, token.PACKAGE:
		// we're '<whatever>.<ident>'
		// parse <ident> as Partial and figure out decl
		tok := iter.token()

		var partial string
		if r == token.IDENT {
			// Calculate the offset of the cursor position within the identifier.
			// For instance, if we are 'ab#c', we want partial_len = 2 and partial = ab.
			partial_len := cursor - tok.off
			// Cursor may be past the end of the literal if there are whitespaces after
			// the identifier, so we bring it back inside the appropriate limits if
			// needed.
			if partial_len > len(tok.Literal()) {
				partial_len = len(tok.Literal())
			}
			partial = tok.Literal()[0:partial_len]
		} else {
			// Do not try to truncate if it is not an identifier.
			partial = tok.Literal()
		}

		iter.previous_token()
		if iter.token().tok == token.PERIOD {
			decl := c.deduce_cursor_decl(&iter)
			return cursor_context{decl, partial}, decl != nil
		} else {
			return cursor_context{nil, partial}, true
		}
	case token.COMMA, token.LBRACE:
		// Try to parse the current expression as a structure initialization.
		data := iter.try_extract_struct_init_expr()
		if data == nil {
			return cursor_context{nil, ""}, true
		}

		expr, err := parser.ParseExpr(string(data))
		if err != nil {
			return cursor_context{nil, ""}, true
		}
		decl := expr_to_decl(expr, c.current.scope)
		if decl == nil {
			return cursor_context{nil, ""}, true
		}

		// Make sure whatever is before the opening brace is a struct.
		switch decl.typ.(type) {
		case *ast.StructType:
			// TODO: Return partial.
			return cursor_context{struct_members_only(decl), ""}, true
		}
	}

	return cursor_context{nil, ""}, true
}

// struct_members_only returns a copy of decl with all its children of type function stripped out.
// This is used when returning matches for struct initialization expressions, for which it does not
// make sense to suggest a function name associated with the struct.
func struct_members_only(decl *decl) *decl {
	new_decl := *decl
	for k, d := range new_decl.children {
		switch d.typ.(type) {
		case *ast.FuncType:
			// Strip functions from the list.
			delete(new_decl.children, k)
		}
	}
	return &new_decl
}

// deduce the type of the expression under the cursor, a bit of copy & paste from the method
// above, returns true if deduction was successful (even if the result of it is nil)
func (c *auto_complete_context) deduce_cursor_type_pkg(file []byte, cursor int) (ast.Expr, string, bool) {
	if cursor <= 0 {
		return nil, "", true
	}

	iter := new_token_iterator(file, cursor)

	// read backwards to extract expression
	e := string(iter.extract_go_expr())

	expr, err := parser.ParseExpr(e)
	if err != nil {
		return nil, "", false
	} else {
		t, scope, _ := infer_type(expr, c.current.scope, -1)
		return t, lookup_pkg(get_type_path(t), scope), t != nil
	}
	return nil, "", false
}
