// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package objc

/*
#cgo CFLAGS: -x objective-c -fobjc-arc
#cgo LDFLAGS: -framework Foundation

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void init_seq();
void go_seq_recv(int32_t, const char*, int, uint8_t*, size_t, uint8_t**, size_t*);
*/
import "C"

import (
	"fmt"
	"sync"
	"unsafe"

	"golang.org/x/mobile/bind/seq"
)

const debug = false

const maxSliceLen = 1<<31 - 1

// Send is called by Objective-C to send a request to run a Go function.
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
		// sender expects results.
		seqToBuf(res, reslen, out)
	}
}

// DestroyRef is called by Objective-C to inform Go it is done with a reference.
//export DestroyRef
func DestroyRef(refnum C.int32_t) {
	seq.Delete(int32(refnum))
}

type request struct {
	ref    *seq.Ref
	handle int32
	code   int
	in     *seq.Buffer
}

var recv struct {
	sync.Mutex
	cond sync.Cond // signals req is not empty
	req  []request
	next int32 // next handle value
}

var res struct {
	sync.Mutex
	cond sync.Cond             // signals a response is filled in
	out  map[int32]*seq.Buffer // handle -> output
}

func init() {
	recv.cond.L = &recv.Mutex
	recv.next = 411 // arbitrary starting point distrinct from Go and Objective-C object ref nums.
	res.cond.L = &res.Mutex
	res.out = make(map[int32]*seq.Buffer)
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

type cStringMap struct {
	sync.Mutex
	m map[string]*C.char
}

var cstrings = &cStringMap{
	m: make(map[string]*C.char),
}

func (s *cStringMap) get(k string) *C.char {
	s.Lock()
	c, ok := s.m[k]
	if !ok {
		c = C.CString(k)
		s.m[k] = c
	}
	s.Unlock()
	return c
}

// transact calls a method on an Objective-C object instance.
// It blocks until the call is complete.
//
// Code (>0) is the method id assigned by gobind.
// Code -1 is used to instruct Objective-C to decrement the ref count of
// the Objective-Co object.
func transact(ref *seq.Ref, descriptor string, code int, in *seq.Buffer) *seq.Buffer {
	var (
		res    *C.uint8_t = nil
		resLen C.size_t   = 0
		req    *C.uint8_t = nil
		reqLen C.size_t   = 0
	)

	if len(in.Data) > 0 {
		req = (*C.uint8_t)(unsafe.Pointer(&in.Data[0]))
		reqLen = C.size_t(len(in.Data))
	}

	if debug {
		fmt.Printf("transact: ref.Num = %d code = %d\n", ref.Num, code)
	}

	desc := cstrings.get(descriptor)
	C.go_seq_recv(C.int32_t(ref.Num), desc, C.int(code), req, reqLen, &res, &resLen)

	if resLen > 0 {
		goSlice := (*[maxSliceLen]byte)(unsafe.Pointer(res))[:resLen]
		out := new(seq.Buffer)
		out.Data = make([]byte, int(resLen))
		copy(out.Data, goSlice)
		C.free(unsafe.Pointer(res))
		// TODO: own or copy []bytes whose addresses were passed in.
		return out
	}
	return nil
}

// finalizeRef notifies Objective-C side of GC of a proxy object from Go side.
func finalizeRef(ref *seq.Ref) {
	if ref.Num < 0 {
		panic(fmt.Sprintf("not an Objective-C ref: %d", ref.Num))
	}
	transact(ref, "", -1, new(seq.Buffer))
}

func init() {
	seq.EncString = func(out *seq.Buffer, v string) {
		out.WriteUTF8(v)
	}
	seq.DecString = func(in *seq.Buffer) string {
		return in.ReadUTF8()
	}
	seq.Transact = transact
	seq.FinalizeRef = finalizeRef

	C.init_seq()
}
