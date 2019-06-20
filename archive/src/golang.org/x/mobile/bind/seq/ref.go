// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package seq

//#cgo LDFLAGS: -llog
//#include <android/log.h>
//#include <string.h>
//import "C"

import (
	"fmt"
	"runtime"
	"sync"
)

type countedObj struct {
	obj interface{}
	cnt int32
}

// also known to bind/java/Seq.java and bind/objc/seq_darwin.m
const NullRefNum = 41

// refs stores Go objects that have been passed to another language.
var refs struct {
	sync.Mutex
	next int32 // next reference number to use for Go object, always negative
	refs map[interface{}]int32
	objs map[int32]countedObj
}

func init() {
	refs.Lock()
	refs.next = -24 // Go objects get negative reference numbers. Arbitrary starting point.
	refs.refs = make(map[interface{}]int32)
	refs.objs = make(map[int32]countedObj)
	refs.Unlock()
}

// A Ref represents a Java or Go object passed across the language
// boundary.
type Ref struct {
	Bind_Num int32
}

type proxy interface {
	// Use a strange name and hope that user code does not implement it
	Bind_proxy_refnum__() int32
}

// ToRefNum increments the reference count for an object and
// returns its refnum.
func ToRefNum(obj interface{}) int32 {
	// We don't track foreign objects, so if obj is a proxy
	// return its refnum.
	if r, ok := obj.(proxy); ok {
		refnum := r.Bind_proxy_refnum__()
		if refnum <= 0 {
			panic(fmt.Errorf("seq: proxy contained invalid Go refnum: %d", refnum))
		}
		return refnum
	}
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

	return int32(num)
}

// FromRefNum returns the Ref for a refnum. If the refnum specifies a
// foreign object, a finalizer is set to track its lifetime.
func FromRefNum(num int32) *Ref {
	if num == NullRefNum {
		return nil
	}
	ref := &Ref{num}
	if num > 0 {
		// This is a foreign object reference.
		// Track its lifetime with a finalizer.
		runtime.SetFinalizer(ref, FinalizeRef)
	}

	return ref
}

// Bind_IncNum increments the foreign reference count and
// return the refnum.
func (r *Ref) Bind_IncNum() int32 {
	refnum := r.Bind_Num
	IncForeignRef(refnum)
	return refnum
}

// Get returns the underlying object.
func (r *Ref) Get() interface{} {
	refnum := r.Bind_Num
	refs.Lock()
	o, ok := refs.objs[refnum]
	refs.Unlock()
	if !ok {
		panic(fmt.Sprintf("unknown ref %d", refnum))
	}
	// This is a Go reference and its refnum was incremented
	// before crossing the language barrier.
	Delete(refnum)
	return o.obj
}

// Inc increments the reference count for a refnum. Called from Bind_proxy_refnum
// functions.
func Inc(num int32) {
	refs.Lock()
	o, ok := refs.objs[num]
	if !ok {
		panic(fmt.Sprintf("seq.Inc: unknown refnum: %d", num))
	}
	refs.objs[num] = countedObj{o.obj, o.cnt + 1}
	refs.Unlock()
}

// Delete decrements the reference count and removes the pinned object
// from the object map when the reference count becomes zero.
func Delete(num int32) {
	refs.Lock()
	defer refs.Unlock()
	o, ok := refs.objs[num]
	if !ok {
		panic(fmt.Sprintf("seq.Delete unknown refnum: %d", num))
	}
	if o.cnt <= 1 {
		delete(refs.objs, num)
		delete(refs.refs, o.obj)
	} else {
		refs.objs[num] = countedObj{o.obj, o.cnt - 1}
	}
}
