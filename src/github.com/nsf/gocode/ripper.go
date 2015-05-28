package main

import (
	"go/scanner"
	"go/token"
)

// All the code in this file serves single purpose:
// It separates a function with the cursor inside and the rest of the code. I'm
// doing that, because sometimes parser is not able to recover itself from an
// error and the autocompletion results become less complete.

type tok_pos_pair struct {
	tok token.Token
	pos token.Pos
}

type tok_collection struct {
	tokens []tok_pos_pair
	fset   *token.FileSet
}

func (this *tok_collection) next(s *scanner.Scanner) bool {
	pos, tok, _ := s.Scan()
	if tok == token.EOF {
		return false
	}

	this.tokens = append(this.tokens, tok_pos_pair{tok, pos})
	return true
}

func (this *tok_collection) find_decl_beg(pos int) int {
	lowest := 0
	lowpos := -1
	lowi := -1
	cur := 0
	for i := pos; i >= 0; i-- {
		t := this.tokens[i]
		switch t.tok {
		case token.RBRACE:
			cur++
		case token.LBRACE:
			cur--
		}

		if cur < lowest {
			lowest = cur
			lowpos = this.fset.Position(t.pos).Offset
			lowi = i
		}
	}

	cur = lowest
	for i := lowi - 1; i >= 0; i-- {
		t := this.tokens[i]
		switch t.tok {
		case token.RBRACE:
			cur++
		case token.LBRACE:
			cur--
		}
		if t.tok == token.SEMICOLON && cur == lowest {
			lowpos = this.fset.Position(t.pos).Offset
			break
		}
	}

	return lowpos
}

func (this *tok_collection) find_decl_end(pos int) int {
	highest := 0
	highpos := -1
	cur := 0

	if this.tokens[pos].tok == token.LBRACE {
		pos++
	}

	for i := pos; i < len(this.tokens); i++ {
		t := this.tokens[i]
		switch t.tok {
		case token.RBRACE:
			cur++
		case token.LBRACE:
			cur--
		}

		if cur > highest {
			highest = cur
			highpos = this.fset.Position(t.pos).Offset
		}
	}

	return highpos
}

func (this *tok_collection) find_outermost_scope(cursor int) (int, int) {
	pos := 0

	for i, t := range this.tokens {
		if cursor <= this.fset.Position(t.pos).Offset {
			break
		}
		pos = i
	}

	return this.find_decl_beg(pos), this.find_decl_end(pos)
}

// return new cursor position, file without ripped part and the ripped part itself
// variants:
//   new-cursor, file-without-ripped-part, ripped-part
//   old-cursor, file, nil
func (this *tok_collection) rip_off_decl(file []byte, cursor int) (int, []byte, []byte) {
	this.fset = token.NewFileSet()
	var s scanner.Scanner
	s.Init(this.fset.AddFile("", this.fset.Base(), len(file)), file, nil, scanner.ScanComments)
	for this.next(&s) {
	}

	beg, end := this.find_outermost_scope(cursor)
	if beg == -1 || end == -1 {
		return cursor, file, nil
	}

	ripped := make([]byte, end+1-beg)
	copy(ripped, file[beg:end+1])

	newfile := make([]byte, len(file)-len(ripped))
	copy(newfile, file[:beg])
	copy(newfile[beg:], file[end+1:])

	return cursor - beg, newfile, ripped
}

func rip_off_decl(file []byte, cursor int) (int, []byte, []byte) {
	var tc tok_collection
	return tc.rip_off_decl(file, cursor)
}
