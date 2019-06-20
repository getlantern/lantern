// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin
// +build arm arm64

package sensor

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework CoreMotion

#import <stdlib.h>

void GoIOS_createManager();

void GoIOS_startAccelerometer(float interval);
void GoIOS_stopAccelerometer();
void GoIOS_readAccelerometer(int64_t* timestamp, float* vector);

void GoIOS_startGyro(float interval);
void GoIOS_stopGyro();
void GoIOS_readGyro(int64_t* timestamp, float* vector);

void GoIOS_startMagneto(float interval);
void GoIOS_stopMagneto();
void GoIOS_readMagneto(int64_t* timestamp, float* vector);

void GoIOS_destroyManager();
*/
import "C"
import (
	"fmt"
	"sync"
	"time"
	"unsafe"
)

var channels struct {
	sync.Mutex
	done [nTypes]chan struct{}
}

func init() {
	C.GoIOS_createManager()
}

// minDelay is the minimum delay allowed.
//
// From Event Handling Guide for iOS:
//
// "You can set the reporting interval to be as small as 10
// milliseconds (ms), which corresponds to a 100 Hz update rate,
// but most app operate sufficiently with a larger interval."
//
// There is no need to poll more frequently than once every 10ms.
//
// https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/motion_event_basics/motion_event_basics.html

const minDelay = 10 * time.Millisecond

// enable enables the sensor t on sender. A non-nil sender is
// required before calling enable.
func enable(t Type, delay time.Duration) error {
	channels.Lock()
	defer channels.Unlock()

	if channels.done[t] != nil {
		return fmt.Errorf("sensor: cannot enable; %v sensor is already enabled", t)
	}
	channels.done[t] = make(chan struct{})

	if delay < minDelay {
		delay = minDelay
	}
	interval := C.float(float64(delay) / float64(time.Second))

	switch t {
	case Accelerometer:
		C.GoIOS_startAccelerometer(interval)
	case Gyroscope:
		C.GoIOS_startGyro(interval)
	case Magnetometer:
		C.GoIOS_startMagneto(interval)
	}
	go pollSensor(t, delay, channels.done[t])
	return nil
}

func disable(t Type) error {
	channels.Lock()
	defer channels.Unlock()

	if channels.done[t] == nil {
		return fmt.Errorf("sensor: cannot disable; %v sensor is not enabled", t)
	}
	close(channels.done[t])
	channels.done[t] = nil

	switch t {
	case Accelerometer:
		C.GoIOS_stopAccelerometer()
	case Gyroscope:
		C.GoIOS_stopGyro()
	case Magnetometer:
		C.GoIOS_stopMagneto()
	}
	return nil
}

func pollSensor(t Type, d time.Duration, done chan struct{}) {
	var lastTimestamp int64

	var timestamp C.int64_t
	var ev [3]C.float

	for {
		select {
		case <-done:
			return
		default:
			tp := (*C.int64_t)(unsafe.Pointer(&timestamp))
			vp := (*C.float)(unsafe.Pointer(&ev[0]))

			switch t {
			case Accelerometer:
				C.GoIOS_readAccelerometer(tp, vp)
			case Gyroscope:
				C.GoIOS_readGyro(tp, vp)
			case Magnetometer:
				C.GoIOS_readMagneto(tp, vp)
			}
			ts := int64(timestamp)
			if ts > lastTimestamp {
				// TODO(jbd): Do we need to convert the values to another unit?
				// How does iOS units compare to the Android units.
				sender.Send(Event{
					Sensor:    t,
					Timestamp: ts,
					Data:      []float64{float64(ev[0]), float64(ev[1]), float64(ev[2])},
				})
				lastTimestamp = ts
				time.Sleep(d / 2)
			}
		}
	}
}

// TODO(jbd): Remove destroy?
func destroy() error {
	C.GoIOS_destroyManager()
	return nil
}
