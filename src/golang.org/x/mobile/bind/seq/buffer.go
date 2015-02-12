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

func (b *Buffer) ReadInt32() int32 {
	if len(b.Data)-b.Offset < 4 {
		b.panic(4)
	}
	v := *(*int32)(unsafe.Pointer(&b.Data[b.Offset]))
	b.Offset += 4
	return v
}

func (b *Buffer) ReadInt64() int64 {
	if len(b.Data)-b.Offset < 8 {
		b.panic(8)
	}
	v := *(*int64)(unsafe.Pointer(&b.Data[b.Offset]))
	b.Offset += 8
	return v
}

func (b *Buffer) ReadInt() int {
	return int(b.ReadInt64())
}

func (b *Buffer) ReadFloat32() float32 {
	if len(b.Data)-b.Offset < 4 {
		b.panic(4)
	}
	v := *(*float32)(unsafe.Pointer(&b.Data[b.Offset]))
	b.Offset += 4
	return v
}

func (b *Buffer) ReadFloat64() float64 {
	if len(b.Data)-b.Offset < 8 {
		b.panic(8)
	}
	v := *(*float64)(unsafe.Pointer(&b.Data[b.Offset]))
	b.Offset += 8
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

func (b *Buffer) WriteInt32(v int32) {
	if len(b.Data)-b.Offset < 4 {
		b.grow(4)
	}
	*(*int32)(unsafe.Pointer(&b.Data[b.Offset])) = v
	b.Offset += 4
}

func (b *Buffer) WriteInt64(v int64) {
	if len(b.Data)-b.Offset < 8 {
		b.grow(8)
	}
	*(*int64)(unsafe.Pointer(&b.Data[b.Offset])) = v
	b.Offset += 8
}

func (b *Buffer) WriteInt(v int) {
	b.WriteInt64(int64(v))
}

func (b *Buffer) WriteFloat32(v float32) {
	if len(b.Data)-b.Offset < 4 {
		b.grow(4)
	}
	*(*float32)(unsafe.Pointer(&b.Data[b.Offset])) = v
	b.Offset += 4
}

func (b *Buffer) WriteFloat64(v float64) {
	if len(b.Data)-b.Offset < 8 {
		b.grow(8)
	}
	*(*float64)(unsafe.Pointer(&b.Data[b.Offset])) = v
	b.Offset += 8
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

func (b *Buffer) WriteGoRef(obj interface{}) {
	refs.Lock()
	num := refs.refs[obj]
	if num == 0 {
		num = refs.next
		refs.next--
		if refs.next > 0 {
			panic("refs.next underflow")
		}
		refs.refs[obj] = num
		refs.objs[num] = obj
	}
	refs.Unlock()

	b.WriteInt32(int32(num))
}

/*  TODO: Will we need it?
func (b *Buffer) WriteRef(ref *Ref) {
	b.WriteInt32(ref.Num)
}
*/
