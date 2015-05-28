// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package objc

/*
#cgo LDFLAGS: -framework Foundation

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
*/
import "C"

import (
	"fmt"
	"unsafe"

	"golang.org/x/mobile/bind/seq"
)

const debug = true

const maxSliceLen = 1<<31 - 1

//export Send
func Send(descriptor string, code int, req *C.uint8_t, reqlen C.size_t, res **C.uint8_t, reslen *C.size_t) {
	fn := seq.Registry[descriptor][code]
	if fn == nil {
		panic(fmt.Sprintf("invalid descriptor(%s) and code(0x%x)", descriptor, code))
	}
	var in, out *seq.Buffer
	if reqlen > 0 {
		in = &seq.Buffer{Data: (*[maxSliceLen]byte)(unsafe.Pointer(req))[:reqlen]}
	}
	if reslen != nil {
		out = new(seq.Buffer)
	}

	fn(out, in)
	if out != nil {
		// sender does not expect any results.
		seqToBuf(res, reslen, out)
	}
}

func seqToBuf(bufptr **C.uint8_t, lenptr *C.size_t, buf *seq.Buffer) {
	if debug {
		fmt.Printf("seqToBuf tag 1, len(buf.Data)=%d, *lenptr=%d\n", len(buf.Data), *lenptr)
	}
	if len(buf.Data) == 0 {
		*lenptr = 0
		return
	}
	if len(buf.Data) > int(*lenptr) {
		// TODO(crawshaw): realloc
		C.free(unsafe.Pointer(*bufptr))
		m := C.malloc(C.size_t(len(buf.Data)))
		if uintptr(m) == 0 {
			panic(fmt.Sprintf("malloc failed, size=%d", len(buf.Data)))
		}
		*bufptr = (*C.uint8_t)(m)
		*lenptr = C.size_t(len(buf.Data))
	}
	C.memcpy(unsafe.Pointer(*bufptr), unsafe.Pointer(&buf.Data[0]), C.size_t(len(buf.Data)))
}

func init() {
	// TODO: seq.FinalizeRef, seq.Transact.

	seq.EncString = func(out *seq.Buffer, v string) {
		out.WriteUTF8(v)
	}
	seq.DecString = func(in *seq.Buffer) string {
		return in.ReadUTF8()
	}
}
