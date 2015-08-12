// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package java // import "golang.org/x/mobile/bind/java"

//#cgo LDFLAGS: -llog
//#include <android/log.h>
//#include <jni.h>
//#include <stdint.h>
//#include <string.h>
//#include "seq_android.h"
import "C"
import (
	"fmt"
	"sync"
	"unsafe"

	"golang.org/x/mobile/bind/seq"
	"golang.org/x/mobile/internal/mobileinit"
)

const maxSliceLen = 1<<31 - 1

const debug = false

// Send is called by Java to send a request to run a Go function.
//export Send
func Send(descriptor string, code int, req *C.uint8_t, reqlen C.size_t, res **C.uint8_t, reslen *C.size_t) {
	fn := seq.Registry[descriptor][code]
	if fn == nil {
		panic(fmt.Sprintf("invalid descriptor(%s) and code(0x%x)", descriptor, code))
	}
	in := new(seq.Buffer)
	if reqlen > 0 {
		in.Data = (*[maxSliceLen]byte)(unsafe.Pointer(req))[:reqlen]
	}
	out := new(seq.Buffer)
	fn(out, in)
	// BUG(hyangah): the function returning a go byte slice (so fn writes a pointer into 'out') is unsafe.
	// After fn is complete here, Go runtime is free to collect or move the pointed byte slice
	// contents. (Explicitly calling runtime.GC here will surface the problem?)
	// Without pinning support from Go side, it will be hard to fix it without extra copying.

	seqToBuf(res, reslen, out)
}

// DestroyRef is called by Java to inform Go it is done with a reference.
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
	recv.next = 411 // arbitrary starting point distinct from Go and Java obj ref nums

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

// Recv is called by Java in a loop and blocks until Go requests a callback
// be executed by the JVM. Then a request object is returned, along with a
// handle for the host to respond via RecvRes.
//export Recv
func Recv(in **C.uint8_t, inlen *C.size_t) (ref, code, handle C.int32_t) {
	recv.Lock()
	for len(recv.req) == 0 {
		recv.cond.Wait()
	}
	req := recv.req[0]
	recv.req = recv.req[1:]
	seqToBuf(in, inlen, req.in)
	recv.Unlock()

	return C.int32_t(req.ref.Num), C.int32_t(req.code), C.int32_t(req.handle)
}

// RecvRes is called by JNI to return the result of a requested callback.
//export RecvRes
func RecvRes(handle C.int32_t, out *C.uint8_t, outlen C.size_t) {
	outBuf := &seq.Buffer{
		Data: make([]byte, outlen),
	}
	copy(outBuf.Data, (*[maxSliceLen]byte)(unsafe.Pointer(out))[:outlen])

	res.Lock()
	res.out[int32(handle)] = outBuf
	res.Unlock()
	res.cond.Broadcast()
}

// transact calls a method on a Java object instance.
// It blocks until the call is complete.
func transact(ref *seq.Ref, _ string, code int, in *seq.Buffer) *seq.Buffer {
	recv.Lock()
	if recv.next == 1<<31-1 {
		panic("recv handle overflow")
	}
	handle := recv.next
	recv.next++
	recv.req = append(recv.req, request{
		ref:    ref,
		code:   code,
		in:     in,
		handle: handle,
	})
	recv.Unlock()
	recv.cond.Signal()

	res.Lock()
	for res.out[handle] == nil {
		res.cond.Wait()
	}
	out := res.out[handle]
	delete(res.out, handle)
	res.Unlock()

	return out
}

func encodeString(out *seq.Buffer, v string) {
	out.WriteUTF16(v)
}

func decodeString(in *seq.Buffer) string {
	return in.ReadUTF16()
}

func init() {
	seq.FinalizeRef = func(ref *seq.Ref) {
		if ref.Num < 0 {
			panic(fmt.Sprintf("not a Java ref: %d", ref.Num))
		}
		transact(ref, "", -1, new(seq.Buffer))
	}

	seq.Transact = transact
	seq.EncString = encodeString
	seq.DecString = decodeString
}

//export setContext
func setContext(vm *C.JavaVM, ctx C.jobject) {
	mobileinit.SetCurrentContext(unsafe.Pointer(vm), unsafe.Pointer(ctx))
}
