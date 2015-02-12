// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package bind

import (
	"bytes"
	"fmt"
)

type printer struct {
	buf        *bytes.Buffer
	indentEach []byte
	indentText []byte
	needIndent bool
}

func (p *printer) writeIndent() error {
	if !p.needIndent {
		return nil
	}
	p.needIndent = false
	_, err := p.buf.Write(p.indentText)
	return err
}

func (p *printer) Write(b []byte) (n int, err error) {
	wrote := 0
	for len(b) > 0 {
		if err := p.writeIndent(); err != nil {
			return wrote, err
		}
		i := bytes.IndexByte(b, '\n')
		if i < 0 {
			break
		}
		n, err = p.buf.Write(b[0 : i+1])
		wrote += n
		if err != nil {
			return wrote, err
		}
		b = b[i+1:]
		p.needIndent = true
	}
	if len(b) > 0 {
		n, err = p.buf.Write(b)
		wrote += n
	}
	return wrote, err
}

func (p *printer) Printf(format string, args ...interface{}) {
	if _, err := fmt.Fprintf(p, format, args...); err != nil {
		panic(fmt.Sprintf("printer: %v", err))
	}
}

func (p *printer) Indent() {
	p.indentText = append(p.indentText, p.indentEach...)
}

func (p *printer) Outdent() {
	if len(p.indentText) > len(p.indentEach)-1 {
		p.indentText = p.indentText[len(p.indentEach):]
	}
}
