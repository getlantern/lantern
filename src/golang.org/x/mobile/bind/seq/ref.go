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
	"sync"
)

type countedObj struct {
	obj interface{}
	cnt int32
}

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
	Num int32
}

// Get returns the underlying object.
func (r *Ref) Get() interface{} {
	refs.Lock()
	o, ok := refs.objs[r.Num]
	refs.Unlock()
	if !ok {
		panic(fmt.Sprintf("unknown ref %d", r.Num))
	}
	return o.obj
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
