// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package sensor

/*
#cgo LDFLAGS: -landroid

#include <stdlib.h>
#include <android/sensor.h>

#include "sensors_android.h"
*/
import "C"
import (
	"fmt"
	"runtime"
	"sync/atomic"
	"time"
	"unsafe"
)

var nextLooperID int64 // each underlying ALooper should have a unique ID.

// initSignal initializes an underlying looper and event queue.
type initSignal struct{}

// closeSignal destroys the underlying looper and event queue.
type closeSignal struct{}

// readSignal reads up to len(dst) events and mutates n with
// the number of returned events. If error occurs during the read,
// it mutates err.
type readSignal struct {
	dst []Event
	n   *int
	err *error
}

// enableSignal enables the sensors events on the underlying
// event queue for the specified sensor type with the specified
// latency criterion.
type enableSignal struct {
	t     Type
	delay time.Duration
	err   *error
}

// disableSignal disables the events on the underlying event queue
// from the sensor specified.
type disableSignal struct {
	t Type
}

type inOut struct {
	in  interface{}
	out chan struct{}
}

// manager is the Android-specific implementation of Manager.
type manager struct {
	m     *C.android_SensorManager
	inout chan inOut
}

// initialize inits the manager and creates a goroutine to proxy the CGO calls.
// All actions related to an ALooper needs to be performed from the same
// OS thread. The goroutine proxy locks itself to an OS thread and handles the
// CGO traffic on the same thread.
func (m *manager) initialize() {
	m.inout = make(chan inOut)

	go func() {
		runtime.LockOSThread()
		for {
			v := <-m.inout
			switch s := v.in.(type) {
			case initSignal:
				id := atomic.AddInt64(&nextLooperID, int64(1))
				var mgr C.android_SensorManager
				C.android_createManager(C.int(id), &mgr)
				m.m = &mgr
			case enableSignal:
				usecsDelay := s.delay.Nanoseconds() * 1000
				code := int(C.android_enableSensor(m.m.queue, typeToInt(s.t), C.int32_t(usecsDelay)))
				if code != 0 {
					*s.err = fmt.Errorf("sensor: no default %v sensor on the device", s.t)
				}
			case disableSignal:
				C.android_disableSensor(m.m.queue, typeToInt(s.t))
			case readSignal:
				n, err := readEvents(m, s.dst)
				*s.n = n
				*s.err = err
			case closeSignal:
				C.android_destroyManager(m.m)
				close(v.out)
				return // we don't need this goroutine anymore
			}
			close(v.out)
		}
	}()

	if m.m == nil {
		done := make(chan struct{})
		m.inout <- inOut{
			in:  initSignal{},
			out: done,
		}
		<-done
	}
}

func (m *manager) enable(t Type, delay time.Duration) error {
	var err error
	done := make(chan struct{})
	m.inout <- inOut{
		in:  enableSignal{t: t, delay: delay, err: &err},
		out: done,
	}
	<-done
	return err
}

func (m *manager) disable(t Type) error {
	done := make(chan struct{})
	m.inout <- inOut{
		in:  disableSignal{t: t},
		out: done,
	}
	<-done
	return nil
}

func (m *manager) read(e []Event) (n int, err error) {
	done := make(chan struct{})
	m.inout <- inOut{
		in:  readSignal{dst: e, n: &n, err: &err},
		out: done,
	}
	<-done
	return
}

func readEvents(m *manager, e []Event) (n int, err error) {
	num := len(e)
	types := make([]C.int32_t, num)
	timestamps := make([]C.int64_t, num)
	vectors := make([]C.float, 3*num)

	n = int(C.android_readQueue(
		m.m.looperId, m.m.queue,
		C.int(num),
		(*C.int32_t)(unsafe.Pointer(&types[0])),
		(*C.int64_t)(unsafe.Pointer(&timestamps[0])),
		(*C.float)(unsafe.Pointer(&vectors[0]))),
	)
	for i := 0; i < n; i++ {
		e[i] = Event{
			Sensor:    intToType[int(types[i])],
			Timestamp: int64(timestamps[i]),
			Data: []float64{
				float64(vectors[i*3]),
				float64(vectors[i*3+1]),
				float64(vectors[i*3+2]),
			},
		}
	}
	return
}

func (m *manager) close() error {
	done := make(chan struct{})
	m.inout <- inOut{
		in:  closeSignal{},
		out: done,
	}
	<-done
	return nil
}

var intToType = map[int]Type{
	C.ASENSOR_TYPE_ACCELEROMETER:  Accelerometer,
	C.ASENSOR_TYPE_GYROSCOPE:      Gyroscope,
	C.ASENSOR_TYPE_MAGNETIC_FIELD: Magnetometer,
}

func typeToInt(t Type) C.int {
	for k, v := range intToType {
		if v == t {
			return C.int(k)
		}
	}
	return C.int(-1)
}
