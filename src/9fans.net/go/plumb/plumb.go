// Package plumb provides routines for sending and receiving messages for the plumber.
package plumb // import "9fans.net/go/plumb"

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
	"sync"

	"9fans.net/go/plan9/client"
)

// Message represents a message to or from the plumber.
type Message struct {
	Src  string     // The source of the message ("acme").
	Dst  string     // The destination port of the message ("edit").
	Dir  string     // The working directory in which to interpret the message.
	Type string     // The type of the message ("text").
	Attr *Attribute // The attributes; may be nil.
	Data []byte     // The data; may be nil.
}

// Attribute represents a list of attributes for a single Message.
type Attribute struct {
	Name  string // The name of the attribute ("addr").
	Value string // The value of the attribute ("/long johns/")
	Next  *Attribute
}

var (
	ErrAttribute = errors.New("bad attribute syntax")
	ErrQuote     = errors.New("bad attribute quoting")
)

var fsys *client.Fsys
var fsysErr error
var fsysOnce sync.Once

func mountPlumb() {
	fsys, fsysErr = client.MountService("plumb")
}

// Open opens the plumbing file with the given name and open mode.
func Open(name string, mode int) (*client.Fid, error) {
	fsysOnce.Do(mountPlumb)
	if fsysErr != nil {
		return nil, fsysErr
	}
	fid, err := fsys.Open(name, uint8(mode))
	if err != nil {
		return nil, err
	}
	return fid, nil
}

// Send writes the message to the writer. The message will be sent with
// a single call to Write.
func (m *Message) Send(w io.Writer) error {
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "%s\n", m.Src)
	fmt.Fprintf(&buf, "%s\n", m.Dst)
	fmt.Fprintf(&buf, "%s\n", m.Dir)
	fmt.Fprintf(&buf, "%s\n", m.Type)
	m.Attr.send(&buf)
	fmt.Fprintf(&buf, "%d\n", len(m.Data))
	buf.Write(m.Data)
	_, err := w.Write(buf.Bytes())
	return err
}

func (attr *Attribute) send(w io.Writer) {
	for a := attr; a != nil; a = a.Next {
		if a != attr {
			fmt.Fprint(w, " ")
		}
		fmt.Fprintf(w, "%s=%s", a.Name, quoteAttribute(a.Value))
	}
	fmt.Fprintf(w, "\n")
}

const quote = '\''

// quoteAttribute quotes the attribute value, if necessary, and returns the result.
func quoteAttribute(s string) string {
	if !strings.ContainsAny(s, " '=\t") {
		return s
	}
	b := make([]byte, 0, 10+len(s)) // Room for a couple of quotes and a few backslashes.
	b = append(b, quote)
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == quote {
			b = append(b, quote)
		}
		b = append(b, c)
	}
	b = append(b, quote)
	return string(b)
}

// Recv reads a message from the reader and stores it in the Message.
// Since encoded messages are properly delimited, Recv will not read
// any data beyond the message itself.
func (m *Message) Recv(r io.ByteReader) error {
	reader := newReader(r)
	m.Src = reader.readLine()
	m.Dst = reader.readLine()
	m.Dir = reader.readLine()
	m.Type = reader.readLine()
	m.Attr = reader.readAttr()
	if reader.err != nil {
		return reader.err
	}
	n, err := strconv.Atoi(reader.readLine())
	if err != nil {
		return err
	}
	m.Data = make([]byte, n)
	reader.read(m.Data)
	return reader.err
}

type reader struct {
	r    io.ByteReader
	buf  []byte
	attr *Attribute
	err  error
}

func newReader(r io.ByteReader) *reader {
	return &reader{
		r:   r,
		buf: make([]byte, 128),
	}
}

func (r *reader) readLine() string {
	r.buf = r.buf[:0]
	var c byte
	for r.err == nil {
		c, r.err = r.r.ReadByte()
		if c == '\n' {
			break
		}
		r.buf = append(r.buf, c)
	}
	return string(r.buf)
}

func (r *reader) read(p []byte) {
	rr, ok := r.r.(io.Reader)
	if r.err == nil && ok {
		_, r.err = rr.Read(p)
		return
	}
	for i := range p {
		if r.err != nil {
			break
		}
		p[i], r.err = r.r.ReadByte()
	}
}

func (r *reader) readAttr() *Attribute {
	r.buf = r.buf[:0]
	var c byte
	quoting := false
Loop:
	for r.err == nil {
		c, r.err = r.r.ReadByte()
		if quoting && c == quote {
			r.buf = append(r.buf, c)
			c, r.err = r.r.ReadByte()
			if c != quote {
				quoting = false
			}
		}
		if !quoting {
			switch c {
			case '\n':
				break Loop
			case quote:
				quoting = true
			case ' ':
				r.newAttr()
				r.buf = r.buf[:0]
				continue Loop // Don't add the space.
			}
		}
		r.buf = append(r.buf, c)
	}
	if len(r.buf) > 0 && r.err == nil {
		r.newAttr()
	}
	// Attributes are ordered so reverse the list.
	var next, rattr *Attribute
	for a := r.attr; a != nil; a = next {
		next = a.Next
		a.Next = rattr
		rattr = a
	}
	return rattr
}

func (r *reader) newAttr() {
	equals := bytes.IndexByte(r.buf, '=')
	if equals < 0 {
		r.err = ErrAttribute
		return
	}
	str := string(r.buf)
	r.attr = &Attribute{
		Name: str[:equals],
		Next: r.attr,
	}
	r.attr.Value, r.err = unquoteAttribute(str[equals+1:])
}

// unquoteAttribute unquotes the attribute value, if necessary, and returns the result.
func unquoteAttribute(s string) (string, error) {
	if !strings.Contains(s, "'") {
		return s, nil
	}
	if len(s) < 2 || s[0] != quote || s[len(s)-1] != quote {
		return s, ErrQuote
	}
	s = s[1 : len(s)-1]
	b := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == quote { // Must be doubled.
			if i == len(s)-1 || s[i+1] != quote {
				return s, ErrQuote
			}
			i++
		}
		b = append(b, c)
	}
	return string(b), nil
}
