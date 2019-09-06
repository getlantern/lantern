// Copyright 2015 The Go Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/xml"
	"fmt"
	"io"
	"sort"
	"strconv"
	"strings"
	"unicode/utf16"
)

// binaryXML converts XML into Android's undocumented binary XML format.
//
// The best source of information on this format seems to be the source code
// in AOSP frameworks-base. Android "resource" types seem to describe the
// encoded bytes, in particular:
//
//	ResChunk_header
//	ResStringPool_header
//	ResXMLTree_node
//
// These are defined in:
//
//	https://android.googlesource.com/platform/frameworks/base/+/master/include/androidfw/ResourceTypes.h
//
// The rough format of the file is a resource chunk containing a sequence of
// chunks. Each chunk is made up of a header and a body. The header begins with
// the contents of the ResChunk_header struct, which includes the size of both
// the header and the body.
//
// Both the header and body are 4-byte aligned.
//
// Values are encoded as little-endian.
//
// The android source code for encoding is done in the aapt tool. Its source
// code lives in AOSP:
//
//	https://android.googlesource.com/platform/frameworks/base.git/+/master/tools/aapt
//
// A sample layout:
//
//	File Header (ResChunk_header, type XML)
//	Chunk: String Pool (type STRING_POOL)
//	Sequence of strings, each with the format:
//		uint16 length
//		uint16 extended_length -- only if top bit set on length
//		UTF-16LE string
//		two zero bytes
//	Resource Map
//		The [i]th 4-byte entry in the resource map corresponds with
//		the [i]th string from the string pool. The 4-bytes are a
//		Resource ID constant defined:
//			http://developer.android.com/reference/android/R.attr.html
//		This appears to be a way to map strings onto enum values.
//	Chunk: Namespace Start (ResXMLTree_node; ResXMLTree_namespaceExt)
//	Chunk: Element Start
//		ResXMLTree_node
//		ResXMLTree_attrExt
//		ResXMLTree_attribute (repeated attributeCount times)
//	Chunk: Element End
//		(ResXMLTree_node; ResXMLTree_endElementExt)
//	...
//	Chunk: Namespace End
func binaryXML(r io.Reader) ([]byte, error) {
	lr := &lineReader{r: r}
	d := xml.NewDecoder(lr)

	pool := new(binStringPool)
	depth := 0
	elements := []chunk{}
	namespaceEnds := make(map[int][]binEndNamespace)

	for {
		line := lr.line(d.InputOffset())
		tok, err := d.Token()
		if err != nil {
			if err == io.EOF {
				break
			}
			return nil, err
		}
		switch tok := tok.(type) {
		case xml.StartElement:
			// uses-sdk is synthesized by the writer, disallow declaration in manifest.
			if tok.Name.Local == "uses-sdk" {
				return nil, fmt.Errorf("unsupported manifest tag <uses-sdk .../>")
			} else if tok.Name.Local == "application" {
				// synthesize <uses-sdk/> before handling <application> token
				attr := xml.Attr{
					Name: xml.Name{
						Space: "http://schemas.android.com/apk/res/android",
						Local: "minSdkVersion",
					},
					Value: "15",
				}
				ba, err := pool.getAttr(attr)
				if err != nil {
					return nil, fmt.Errorf("failed to synthesize attr minSdkVersion=\"15\"")
				}
				elements = append(elements,
					&binStartElement{
						line: line - 1, // current testing strategy is not friendly to synthesized tags, -1 for would-be location
						ns:   pool.getNS(""),
						name: pool.get("uses-sdk"),
						attr: []*binAttr{ba},
					},
					&binEndElement{
						line: line - 1,
						ns:   pool.getNS(""),
						name: pool.get("uses-sdk"),
					})
			}
			// Intercept namespace definitions.
			var attr []*binAttr
			for _, a := range tok.Attr {
				if a.Name.Space == "xmlns" {
					elements = append(elements, binStartNamespace{
						line:   line,
						prefix: pool.get(a.Name.Local),
						url:    pool.get(a.Value),
					})
					namespaceEnds[depth] = append([]binEndNamespace{{
						line:   line,
						prefix: pool.get(a.Name.Local),
						url:    pool.get(a.Value),
					}}, namespaceEnds[depth]...)
					continue
				}
				ba, err := pool.getAttr(a)
				if err != nil {
					return nil, fmt.Errorf("%d: %s: %v", line, a.Name.Local, err)
				}
				attr = append(attr, ba)
			}

			depth++
			elements = append(elements, &binStartElement{
				line: line,
				ns:   pool.getNS(tok.Name.Space),
				name: pool.get(tok.Name.Local),
				attr: attr,
			})
		case xml.EndElement:
			elements = append(elements, &binEndElement{
				line: line,
				ns:   pool.getNS(tok.Name.Space),
				name: pool.get(tok.Name.Local),
			})
			depth--
			if nsEnds := namespaceEnds[depth]; len(nsEnds) > 0 {
				delete(namespaceEnds, depth)
				for _, nsEnd := range nsEnds {
					elements = append(elements, nsEnd)
				}
			}
		case xml.CharData:
			// The aapt tool appears to "compact" leading and
			// trailing whitepsace. See XMLNode::removeWhitespace in
			// https://android.googlesource.com/platform/frameworks/base.git/+/master/tools/aapt/XMLNode.cpp
			if len(tok) == 0 {
				continue
			}
			start, end := 0, len(tok)
			for start < len(tok) && isSpace(tok[start]) {
				start++
			}
			for end > start && isSpace(tok[end-1]) {
				end--
			}
			if start == end {
				continue // all whitespace, skip it
			}

			// Preserve one character of whitespace.
			if start > 0 {
				start--
			}
			if end < len(tok) {
				end++
			}

			elements = append(elements, &binCharData{
				line: line,
				data: pool.get(string(tok[start:end])),
			})
		case xml.Comment:
			// Ignored by Anroid Binary XML format.
		case xml.ProcInst:
			// Ignored by Anroid Binary XML format?
		case xml.Directive:
			// Ignored by Anroid Binary XML format.
		default:
			return nil, fmt.Errorf("apk: unexpected token: %v (%T)", tok, tok)
		}
	}

	sortPool(pool)
	for _, e := range elements {
		if e, ok := e.(*binStartElement); ok {
			sortAttr(e, pool)
		}
	}

	resMap := &binResMap{pool}

	size := 8 + pool.size() + resMap.size()
	for _, e := range elements {
		size += e.size()
	}

	b := make([]byte, 0, size)
	b = appendHeader(b, headerXML, size)
	b = pool.append(b)
	b = resMap.append(b)
	for _, e := range elements {
		b = e.append(b)
	}

	return b, nil
}

func isSpace(b byte) bool {
	switch b {
	case '\t', '\n', '\v', '\f', '\r', ' ', 0x85, 0xA0:
		return true
	}
	return false
}

type headerType uint16

const (
	headerXML            headerType = 0x0003
	headerStringPool                = 0x0001
	headerResourceMap               = 0x0180
	headerStartNamespace            = 0x0100
	headerEndNamespace              = 0x0101
	headerStartElement              = 0x0102
	headerEndElement                = 0x0103
	headerCharData                  = 0x0104
)

func appendU16(b []byte, v uint16) []byte {
	return append(b, byte(v), byte(v>>8))
}

func appendU32(b []byte, v uint32) []byte {
	return append(b, byte(v), byte(v>>8), byte(v>>16), byte(v>>24))
}

func appendHeader(b []byte, typ headerType, size int) []byte {
	b = appendU16(b, uint16(typ))
	b = appendU16(b, 8)
	b = appendU16(b, uint16(size))
	b = appendU16(b, 0)
	return b
}

// Attributes of the form android:key are mapped to resource IDs, which are
// embedded into the Binary XML format.
//
// http://developer.android.com/reference/android/R.attr.html
var resourceCodes = map[string]uint32{
	"versionCode":       0x0101021b,
	"versionName":       0x0101021c,
	"minSdkVersion":     0x0101020c,
	"windowFullscreen":  0x0101020d,
	"theme":             0x01010000,
	"label":             0x01010001,
	"hasCode":           0x0101000c,
	"debuggable":        0x0101000f,
	"name":              0x01010003,
	"screenOrientation": 0x0101001e,
	"configChanges":     0x0101001f,
	"value":             0x01010024,
}

// http://developer.android.com/reference/android/R.attr.html#configChanges
var configChanges = map[string]uint32{
	"mcc":                0x0001,
	"mnc":                0x0002,
	"locale":             0x0004,
	"touchscreen":        0x0008,
	"keyboard":           0x0010,
	"keyboardHidden":     0x0020,
	"navigation":         0x0040,
	"orientation":        0x0080,
	"screenLayout":       0x0100,
	"uiMode":             0x0200,
	"screenSize":         0x0400,
	"smallestScreenSize": 0x0800,
	"layoutDirection":    0x2000,
	"fontScale":          0x40000000,
}

// http://developer.android.com/reference/android/R.attr.html#screenOrientation
var screenOrientation = map[string]int{
	"unspecified":      -1,
	"landscape":        0,
	"portrait":         1,
	"user":             2,
	"behind":           3,
	"sensor":           4,
	"nosensor":         5,
	"sensorLandscape":  6,
	"sensorPortrait":   7,
	"reverseLandscape": 8,
	"reversePortrait":  9,
	"fullSensor":       10,
	"userLandscape":    11,
	"userPortrait":     12,
	"fullUser":         13,
	"locked":           14,
}

// reference is an alias used to write out correct type in bin.
type reference uint32

// http://developer.android.com/reference/android/R.style.html
var theme = map[string]reference{
	"Theme":                                   0x01030005,
	"Theme_NoTitleBar":                        0x01030006,
	"Theme_NoTitleBar_Fullscreen":             0x01030007,
	"Theme_Black":                             0x01030008,
	"Theme_Black_NoTitleBar":                  0x01030009,
	"Theme_Black_NoTitleBar_Fullscreen":       0x0103000a,
	"Theme_Light":                             0x0103000c,
	"Theme_Light_NoTitleBar":                  0x0103000d,
	"Theme_Light_NoTitleBar_Fullscreen":       0x0103000e,
	"Theme_Translucent":                       0x0103000f,
	"Theme_Translucent_NoTitleBar":            0x01030010,
	"Theme_Translucent_NoTitleBar_Fullscreen": 0x01030011,
}

type lineReader struct {
	off   int64
	lines []int64
	r     io.Reader
}

func (r *lineReader) Read(p []byte) (n int, err error) {
	n, err = r.r.Read(p)
	for i := 0; i < n; i++ {
		if p[i] == '\n' {
			r.lines = append(r.lines, r.off+int64(i))
		}
	}
	r.off += int64(n)
	return n, err
}

func (r *lineReader) line(pos int64) int {
	return sort.Search(len(r.lines), func(i int) bool {
		return pos < r.lines[i]
	}) + 1
}

type bstring struct {
	ind uint32
	str string
	enc []byte // 2-byte length, utf16le, 2-byte zero
}

type chunk interface {
	size() int
	append([]byte) []byte
}

type binResMap struct {
	pool *binStringPool
}

func (p *binResMap) append(b []byte) []byte {
	b = appendHeader(b, headerResourceMap, p.size())
	for _, bstr := range p.pool.s {
		c, ok := resourceCodes[bstr.str]
		if !ok {
			break
		}
		b = appendU32(b, c)
	}
	return b
}

func (p *binResMap) size() int {
	count := 0
	for _, bstr := range p.pool.s {
		if _, ok := resourceCodes[bstr.str]; !ok {
			break
		}
		count++
	}
	return 8 + 4*count
}

type binStringPool struct {
	s []*bstring
	m map[string]*bstring
}

func (p *binStringPool) get(str string) *bstring {
	if p.m == nil {
		p.m = make(map[string]*bstring)
	}
	res := p.m[str]
	if res != nil {
		return res
	}
	res = &bstring{
		ind: uint32(len(p.s)),
		str: str,
	}
	p.s = append(p.s, res)
	p.m[str] = res

	if len(str)>>16 > 0 {
		panic(fmt.Sprintf("string lengths over 1<<15 not yet supported, got len %d for string that starts %q", len(str), str[:100]))
	}
	strUTF16 := utf16.Encode([]rune(str))
	res.enc = appendU16(nil, uint16(len(strUTF16)))
	for _, w := range strUTF16 {
		res.enc = appendU16(res.enc, w)
	}
	res.enc = appendU16(res.enc, 0)
	return res
}

func (p *binStringPool) getNS(ns string) *bstring {
	if ns == "" {
		// Register empty string for inclusion in output (like aapt),
		// but do not reference it from namespace elements.
		p.get("")
		return nil
	}
	return p.get(ns)
}

func (p *binStringPool) getAttr(attr xml.Attr) (*binAttr, error) {
	a := &binAttr{
		ns:   p.getNS(attr.Name.Space),
		name: p.get(attr.Name.Local),
	}
	if attr.Name.Space != "http://schemas.android.com/apk/res/android" {
		a.data = p.get(attr.Value)
		return a, nil
	}

	// Some android attributes have interesting values.
	switch attr.Name.Local {
	case "versionCode", "minSdkVersion":
		v, err := strconv.Atoi(attr.Value)
		if err != nil {
			return nil, err
		}
		a.data = int(v)
	case "hasCode", "debuggable":
		v, err := strconv.ParseBool(attr.Value)
		if err != nil {
			return nil, err
		}
		a.data = v
	case "configChanges":
		v := uint32(0)
		for _, c := range strings.Split(attr.Value, "|") {
			v |= configChanges[c]
		}
		a.data = v
	case "screenOrientation":
		v := 0
		for _, c := range strings.Split(attr.Value, "|") {
			v |= screenOrientation[c]
		}
		a.data = v
	case "theme":
		v := attr.Value
		// strip prefix if present as only platform themes are supported
		if idx := strings.Index(attr.Value, "/"); idx != -1 {
			v = v[idx+1:]
		}
		v = strings.Replace(v, ".", "_", -1)
		a.data = theme[v]
	default:
		a.data = p.get(attr.Value)
	}
	return a, nil
}

const stringPoolPreamble = 0 +
	8 + // chunk header
	4 + // string count
	4 + // style count
	4 + // flags
	4 + // strings start
	4 + // styles start
	0

func (p *binStringPool) unpaddedSize() int {
	strLens := 0
	for _, s := range p.s {
		strLens += len(s.enc)
	}
	return stringPoolPreamble + 4*len(p.s) + strLens
}

func (p *binStringPool) size() int {
	size := p.unpaddedSize()
	size += size % 0x04
	return size
}

// overloaded for testing.
var (
	sortPool = func(p *binStringPool) {
		sort.Sort(p)

		// Move resourceCodes to the front.
		s := make([]*bstring, 0)
		m := make(map[string]*bstring)
		for str := range resourceCodes {
			bstr := p.m[str]
			if bstr == nil {
				continue
			}
			bstr.ind = uint32(len(s))
			s = append(s, bstr)
			m[str] = bstr
			delete(p.m, str)
		}
		for _, bstr := range p.m {
			bstr.ind = uint32(len(s))
			s = append(s, bstr)
		}
		p.s = s
		p.m = m
	}
	sortAttr = func(e *binStartElement, p *binStringPool) {}
)

func (b *binStringPool) Len() int           { return len(b.s) }
func (b *binStringPool) Less(i, j int) bool { return b.s[i].str < b.s[j].str }
func (b *binStringPool) Swap(i, j int) {
	b.s[i], b.s[j] = b.s[j], b.s[i]
	b.s[i].ind, b.s[j].ind = b.s[j].ind, b.s[i].ind
}

func (p *binStringPool) append(b []byte) []byte {
	stringsStart := uint32(stringPoolPreamble + 4*len(p.s))
	b = appendU16(b, uint16(headerStringPool))
	b = appendU16(b, 0x1c) // chunk header size
	b = appendU16(b, uint16(p.size()))
	b = appendU16(b, 0)
	b = appendU32(b, uint32(len(p.s)))
	b = appendU32(b, 0) // style count
	b = appendU32(b, 0) // flags
	b = appendU32(b, stringsStart)
	b = appendU32(b, 0) // styles start

	off := 0
	for _, bstr := range p.s {
		b = appendU32(b, uint32(off))
		off += len(bstr.enc)
	}
	for _, bstr := range p.s {
		b = append(b, bstr.enc...)
	}

	for i := p.unpaddedSize() % 0x04; i > 0; i-- {
		b = append(b, 0)
	}
	return b
}

type binStartElement struct {
	line int
	ns   *bstring
	name *bstring
	attr []*binAttr
}

func (e *binStartElement) size() int {
	return 8 + // chunk header
		4 + // line number
		4 + // comment
		4 + // ns
		4 + // name
		2 + 2 + 2 + // attribute start, size, count
		2 + 2 + 2 + // id/class/style index
		len(e.attr)*(4+4+4+4+4)
}

func (e *binStartElement) append(b []byte) []byte {
	b = appendU16(b, uint16(headerStartElement))
	b = appendU16(b, 0x10) // chunk header size
	b = appendU16(b, uint16(e.size()))
	b = appendU16(b, 0)
	b = appendU32(b, uint32(e.line))
	b = appendU32(b, 0xffffffff) // comment
	if e.ns == nil {
		b = appendU32(b, 0xffffffff)
	} else {
		b = appendU32(b, e.ns.ind)
	}
	b = appendU32(b, e.name.ind)
	b = appendU16(b, 0x14) // attribute start
	b = appendU16(b, 0x14) // attribute size
	b = appendU16(b, uint16(len(e.attr)))
	b = appendU16(b, 0) // ID index (none)
	b = appendU16(b, 0) // class index (none)
	b = appendU16(b, 0) // style index (none)
	for _, a := range e.attr {
		b = a.append(b)
	}
	return b
}

type binAttr struct {
	ns   *bstring
	name *bstring
	data interface{} // either int (INT_DEC) or *bstring (STRING)
}

func (a *binAttr) append(b []byte) []byte {
	if a.ns != nil {
		b = appendU32(b, a.ns.ind)
	} else {
		b = appendU32(b, 0xffffffff)
	}
	b = appendU32(b, a.name.ind)
	switch v := a.data.(type) {
	case int:
		b = appendU32(b, 0xffffffff) // raw value
		b = appendU16(b, 8)          // size
		b = append(b, 0)             // unused padding
		b = append(b, 0x10)          // INT_DEC
		b = appendU32(b, uint32(v))
	case bool:
		b = appendU32(b, 0xffffffff) // raw value
		b = appendU16(b, 8)          // size
		b = append(b, 0)             // unused padding
		b = append(b, 0x12)          // INT_BOOLEAN
		if v {
			b = appendU32(b, 0xffffffff)
		} else {
			b = appendU32(b, 0)
		}
	case uint32:
		b = appendU32(b, 0xffffffff) // raw value
		b = appendU16(b, 8)          // size
		b = append(b, 0)             // unused padding
		b = append(b, 0x11)          // INT_HEX
		b = appendU32(b, uint32(v))
	case reference:
		b = appendU32(b, 0xffffffff) // raw value
		b = appendU16(b, 8)          // size
		b = append(b, 0)             // unused padding
		b = append(b, 0x01)          // REFERENCE
		b = appendU32(b, uint32(v))
	case *bstring:
		b = appendU32(b, v.ind) // raw value
		b = appendU16(b, 8)     // size
		b = append(b, 0)        // unused padding
		b = append(b, 0x03)     // STRING
		b = appendU32(b, v.ind)
	default:
		panic(fmt.Sprintf("unexpected attr type: %T (%v)", v, v))
	}
	return b
}

type binEndElement struct {
	line int
	ns   *bstring
	name *bstring
	attr []*binAttr
}

func (*binEndElement) size() int {
	return 8 + // chunk header
		4 + // line number
		4 + // comment
		4 + // ns
		4 // name
}

func (e *binEndElement) append(b []byte) []byte {
	b = appendU16(b, uint16(headerEndElement))
	b = appendU16(b, 0x10) // chunk header size
	b = appendU16(b, uint16(e.size()))
	b = appendU16(b, 0)
	b = appendU32(b, uint32(e.line))
	b = appendU32(b, 0xffffffff) // comment
	if e.ns == nil {
		b = appendU32(b, 0xffffffff)
	} else {
		b = appendU32(b, e.ns.ind)
	}
	b = appendU32(b, e.name.ind)
	return b
}

type binStartNamespace struct {
	line   int
	prefix *bstring
	url    *bstring
}

func (binStartNamespace) size() int {
	return 8 + // chunk header
		4 + // line number
		4 + // comment
		4 + // prefix
		4 // url
}

func (e binStartNamespace) append(b []byte) []byte {
	b = appendU16(b, uint16(headerStartNamespace))
	b = appendU16(b, 0x10) // chunk header size
	b = appendU16(b, uint16(e.size()))
	b = appendU16(b, 0)
	b = appendU32(b, uint32(e.line))
	b = appendU32(b, 0xffffffff) // comment
	b = appendU32(b, e.prefix.ind)
	b = appendU32(b, e.url.ind)
	return b
}

type binEndNamespace struct {
	line   int
	prefix *bstring
	url    *bstring
}

func (binEndNamespace) size() int {
	return 8 + // chunk header
		4 + // line number
		4 + // comment
		4 + // prefix
		4 // url
}

func (e binEndNamespace) append(b []byte) []byte {
	b = appendU16(b, uint16(headerEndNamespace))
	b = appendU16(b, 0x10) // chunk header size
	b = appendU16(b, uint16(e.size()))
	b = appendU16(b, 0)
	b = appendU32(b, uint32(e.line))
	b = appendU32(b, 0xffffffff) // comment
	b = appendU32(b, e.prefix.ind)
	b = appendU32(b, e.url.ind)
	return b
}

type binCharData struct {
	line int
	data *bstring
}

func (*binCharData) size() int {
	return 8 + // chunk header
		4 + // line number
		4 + // comment
		4 + // data
		8 // junk
}

func (e *binCharData) append(b []byte) []byte {
	b = appendU16(b, uint16(headerCharData))
	b = appendU16(b, 0x10) // chunk header size
	b = appendU16(b, 0x1c) // size
	b = appendU16(b, 0)
	b = appendU32(b, uint32(e.line))
	b = appendU32(b, 0xffffffff) // comment
	b = appendU32(b, e.data.ind)
	b = appendU16(b, 0x08)
	b = appendU16(b, 0)
	b = appendU16(b, 0)
	b = appendU16(b, 0)
	return b
}
