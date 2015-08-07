// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

import (
	"bytes"
	"fmt"
	"runtime"
	"unsafe"
)

// Buffer is a set of arguments or return values from a function call
// across the language boundary. Encoding is machine-dependent.
type Buffer struct {
	Data   []byte
	Offset int // position of next read/write from Data
}

func (b *Buffer) String() string {
	// Debugging.
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "seq{Off=%d, Len=%d Data=", b.Offset, len(b.Data))
	const hextable = "0123456789abcdef"
	for i, v := range b.Data {
		if i > 0 {
			buf.WriteByte(':')
		}
		buf.WriteByte(hextable[v>>4])
		buf.WriteByte(hextable[v&0x0f])
	}
	buf.WriteByte('}')
	return buf.String()
}

func (b *Buffer) panic(need int) {
	panic(fmt.Sprintf("need %d bytes: %s", need, b))
}

func (b *Buffer) grow(need int) {
	size := len(b.Data)
	if size == 0 {
		size = 2
	}
	for size < need {
		size *= 2
	}
	data := make([]byte, size+len(b.Data))
	copy(data, b.Data[:b.Offset])
	b.Data = data
}

// align returns the aligned offset.
func align(offset, alignment int) int {
	pad := offset % alignment
	if pad > 0 {
		pad = alignment - pad
	}
	return pad + offset
}

func (b *Buffer) ReadInt8() int8 {
	offset := b.Offset
	if len(b.Data)-offset < 1 {
		b.panic(1)
	}
	v := *(*int8)(unsafe.Pointer(&b.Data[offset]))
	b.Offset++
	return v
}

func (b *Buffer) ReadInt16() int16 {
	offset := align(b.Offset, 2)
	if len(b.Data)-offset < 2 {
		b.panic(2)
	}
	v := *(*int16)(unsafe.Pointer(&b.Data[offset]))
	b.Offset = offset + 2
	return v
}

func (b *Buffer) ReadInt32() int32 {
	offset := align(b.Offset, 4)
	if len(b.Data)-offset < 4 {
		b.panic(4)
	}
	v := *(*int32)(unsafe.Pointer(&b.Data[offset]))
	b.Offset = offset + 4
	return v
}

func (b *Buffer) ReadInt64() int64 {
	offset := align(b.Offset, 8)
	if len(b.Data)-offset < 8 {
		b.panic(8)
	}
	v := *(*int64)(unsafe.Pointer(&b.Data[offset]))
	b.Offset = offset + 8
	return v
}

func (b *Buffer) ReadBool() bool {
	return b.ReadInt8() != 0
}

func (b *Buffer) ReadInt() int {
	return int(b.ReadInt64())
}

func (b *Buffer) ReadFloat32() float32 {
	offset := align(b.Offset, 4)
	if len(b.Data)-offset < 4 {
		b.panic(4)
	}
	v := *(*float32)(unsafe.Pointer(&b.Data[offset]))
	b.Offset = offset + 4
	return v
}

func (b *Buffer) ReadFloat64() float64 {
	offset := align(b.Offset, 8)
	if len(b.Data)-offset < 8 {
		b.panic(8)
	}
	v := *(*float64)(unsafe.Pointer(&b.Data[offset]))
	b.Offset = offset + 8
	return v
}

func (b *Buffer) ReadByteArray() []byte {
	sz := b.ReadInt64()
	if sz == 0 {
		return nil
	}

	ptr := b.ReadInt64()
	org := (*[1 << 30]byte)(unsafe.Pointer(uintptr(ptr)))[:sz]

	// Make a copy managed by Go, so the returned byte array can be
	// used safely in Go.
	slice := make([]byte, sz)
	copy(slice, org)
	return slice
}

func (b *Buffer) ReadRef() *Ref {
	ref := &Ref{b.ReadInt32()}
	if ref.Num > 0 {
		// This is a foreign object reference.
		// Track its lifetime with a finalizer.
		runtime.SetFinalizer(ref, FinalizeRef)
	}
	return ref
}

func (b *Buffer) ReadString() string {
	return DecString(b)
}

func (b *Buffer) WriteInt8(v int8) {
	offset := b.Offset
	if len(b.Data)-offset < 1 {
		b.grow(offset + 1 - len(b.Data))
	}
	*(*int8)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset++
}

func (b *Buffer) WriteInt16(v int16) {
	offset := align(b.Offset, 2)
	if len(b.Data)-offset < 2 {
		b.grow(offset + 2 - len(b.Data))
	}
	*(*int16)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset = offset + 2
}

func (b *Buffer) WriteInt32(v int32) {
	offset := align(b.Offset, 4)
	if len(b.Data)-offset < 4 {
		b.grow(offset + 4 - len(b.Data))
	}
	*(*int32)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset = offset + 4
}

func (b *Buffer) WriteInt64(v int64) {
	offset := align(b.Offset, 8)
	if len(b.Data)-offset < 8 {
		b.grow(offset + 8 - len(b.Data))
	}
	*(*int64)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset = offset + 8
}

func (b *Buffer) WriteBool(v bool) {
	if v {
		b.WriteInt8(1)
	} else {
		b.WriteInt8(0)
	}
}

func (b *Buffer) WriteInt(v int) {
	b.WriteInt64(int64(v))
}

func (b *Buffer) WriteFloat32(v float32) {
	offset := align(b.Offset, 4)
	if len(b.Data)-offset < 4 {
		b.grow(offset + 4 - len(b.Data))
	}
	*(*float32)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset = offset + 4
}

func (b *Buffer) WriteFloat64(v float64) {
	offset := align(b.Offset, 8)
	if len(b.Data)-offset < 8 {
		b.grow(offset + 8 - len(b.Data))
	}
	*(*float64)(unsafe.Pointer(&b.Data[offset])) = v
	b.Offset = offset + 8
}

func (b *Buffer) WriteByteArray(byt []byte) {
	sz := len(byt)
	if sz == 0 {
		b.WriteInt64(int64(sz))
		return
	}

	ptr := uintptr(unsafe.Pointer(&byt[0]))
	b.WriteInt64(int64(sz))
	b.WriteInt64(int64(ptr))
	return
}

func (b *Buffer) WriteString(v string) {
	EncString(b, v)
}

func (b *Buffer) WriteGoRef(obj interface{}) {
	refs.Lock()
	num := refs.refs[obj]
	if num != 0 {
		s := refs.objs[num]
		refs.objs[num] = countedObj{s.obj, s.cnt + 1}
	} else {
		num = refs.next
		refs.next--
		if refs.next > 0 {
			panic("refs.next underflow")
		}
		refs.refs[obj] = num
		refs.objs[num] = countedObj{obj, 1}
	}
	refs.Unlock()

	b.WriteInt32(int32(num))
}

/*  TODO: Will we need it?
func (b *Buffer) WriteRef(ref *Ref) {
	b.WriteInt32(ref.Num)
}
*/
