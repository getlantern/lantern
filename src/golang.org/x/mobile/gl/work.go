// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

package gl

/*
#cgo darwin,amd64  LDFLAGS: -framework OpenGL
#cgo darwin,arm    LDFLAGS: -framework OpenGLES
#cgo darwin,arm64  LDFLAGS: -framework OpenGLES
#cgo linux         LDFLAGS: -lGLESv2

#cgo darwin,amd64  CFLAGS: -Dos_osx
#cgo darwin,arm    CFLAGS: -Dos_ios
#cgo darwin,arm64  CFLAGS: -Dos_ios
#cgo linux         CFLAGS: -Dos_linux

#include <stdint.h>
#include "work.h"

struct fnargs cargs[10];
uintptr_t ret;

void process(int count) {
	int i;
	for (i = 0; i < count; i++) {
		processFn(&cargs[i]);
	}
}
*/
import "C"

// work is a queue of calls to execute.
var work = make(chan call, 10)

// retvalue is sent a return value when blocking calls complete.
// It is safe to use a global unbuffered channel here as calls
// cannot currently be made concurrently.
//
// TODO: the comment above about concurrent calls isn't actually true: package
// app calls package gl, but it has to do so in a separate goroutine, which
// means that its gl calls (which may be blocking) can race with other gl calls
// in the main program. We should make it safe to issue blocking gl calls
// concurrently, or get the gl calls out of package app, or both.
var retvalue = make(chan C.uintptr_t)

type call struct {
	args     C.struct_fnargs
	blocking bool
}

func enqueue(c call) C.uintptr_t {
	work <- c

	select {
	case workAvailable <- struct{}{}:
	default:
	}

	if c.blocking {
		return <-retvalue
	}
	return 0
}

var (
	workAvailable = make(chan struct{}, 1)
	// WorkAvailable communicates when DoWork should be called.
	//
	// This is an internal implementation detail and should only be used by the
	// golang.org/x/mobile/app package.
	WorkAvailable <-chan struct{} = workAvailable
)

// DoWork performs any pending OpenGL calls.
//
// This is an internal implementation detail and should only be used by the
// golang.org/x/mobile/app package.
func DoWork() {
	queue := make([]call, 0, len(work))
	for {
		// Wait until at least one piece of work is ready.
		// Accumulate work until a piece is marked as blocking.
		select {
		case w := <-work:
			queue = append(queue, w)
		default:
			return
		}
		blocking := queue[len(queue)-1].blocking
	enqueue:
		for len(queue) < cap(queue) && !blocking {
			select {
			case w := <-work:
				queue = append(queue, w)
				blocking = queue[len(queue)-1].blocking
			default:
				break enqueue
			}
		}

		// Process the queued GL functions.
		for i, q := range queue {
			C.cargs[i] = q.args
		}
		C.process(C.int(len(queue)))

		// Cleanup and signal.
		queue = queue[:0]
		if blocking {
			retvalue <- C.ret
		}
	}
}

func glBoolean(b bool) C.uintptr_t {
	if b {
		return TRUE
	}
	return FALSE
}
