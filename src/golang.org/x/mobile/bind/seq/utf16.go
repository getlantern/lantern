// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import (
	"errors"
	"fmt"
	"unicode/utf16"
	"unsafe"
)

// Based heavily on package unicode/utf16 from the Go standard library.

const (
	replacementChar = '\uFFFD'     // Unicode replacement character
	maxRune         = '\U0010FFFF' // Maximum valid Unicode code point.
)

const (
	// 0xd800-0xdc00 encodes the high 10 bits of a pair.
	// 0xdc00-0xe000 encodes the low 10 bits of a pair.
	// the value is those 20 bits plus 0x10000.
	surr1 = 0xd800
	surr2 = 0xdc00
	surr3 = 0xe000

	surrSelf = 0x10000
)

func writeUint16(b []byte, v rune) {
	*(*uint16)(unsafe.Pointer(&b[0])) = uint16(v)
}

func (b *Buffer) WriteUTF16(s string) {
	// first 4 bytes is the length, as int32. written last.
	// next n bytes is utf-16 string.
	if len(b.Data)-b.Offset < 4+4*len(s) {
		b.grow(4 + 4*len(s)) // worst case estimate, everything is surrogate pair
	}
	data := b.Data[b.Offset+4:]
	n := 0
	for _, v := range s {
		switch {
		case v < 0, surr1 <= v && v < surr3, v > maxRune:
			v = replacementChar
			fallthrough
		case v < surrSelf:
			writeUint16(data[n:], v)
			n += 2
		default:
			// surrogate pair, two uint16 values
			r1, r2 := utf16.EncodeRune(v)
			writeUint16(data[n:], r1)
			writeUint16(data[n+2:], r2)
			n += 4
		}
	}

	// write length at b.Data[b.Offset:], before contents.
	// length is number of uint16 values, not number of bytes.
	b.WriteInt32(int32(n / 2))

	b.Offset += n
}

const maxSliceLen = (1<<31 - 1) / 2

func (b *Buffer) ReadError() error {
	if s := b.ReadUTF16(); s != "" {
		return errors.New(s)
	}
	return nil
}

func (b *Buffer) ReadUTF16() string {
	size := int(b.ReadInt32())
	if size == 0 {
		return ""
	}
	if size < 0 {
		panic(fmt.Sprintf("string size negative: %d", size))
	}
	u := (*[maxSliceLen]uint16)(unsafe.Pointer(&b.Data[b.Offset]))[:size]
	s := string(utf16.Decode(u)) // TODO: save the []rune alloc
	b.Offset += 2 * size

	return s
}
