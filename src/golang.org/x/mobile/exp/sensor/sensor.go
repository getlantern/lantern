// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package sensor provides sensor events from various movement sensors.
package sensor // import "golang.org/x/mobile/exp/sensor"

import (
	"errors"
	"time"
)

// Type represents a sensor type.
type Type int

var sensorNames = map[Type]string{
	Accelerometer: "Accelerometer",
	Gyroscope:     "Gyrsocope",
	Magnetometer:  "Magnetometer",
}

// String returns the string representation of the sensor type.
func (t Type) String() string {
	if n, ok := sensorNames[t]; ok {
		return n
	}
	return "Unknown sensor"
}

const (
	Accelerometer = Type(0)
	Gyroscope     = Type(1)
	Magnetometer  = Type(2)
)

// Event represents a sensor event.
type Event struct {
	// Sensor is the type of the sensor the event is coming from.
	Sensor Type

	// Timestamp is a device specific event time in nanoseconds.
	// Timestamps are not Unix times, they represent a time that is
	// only valid for the device's default sensor.
	Timestamp int64

	// Data is the event data.
	//
	// If the event source is Accelerometer,
	//  - Data[0]: acceleration force in x axis in m/s^2
	//  - Data[1]: acceleration force in y axis in m/s^2
	//  - Data[2]: acceleration force in z axis in m/s^2
	//
	// If the event source is Gyroscope,
	//  - Data[0]: rate of rotation around the x axis in rad/s
	//  - Data[1]: rate of rotation around the y axis in rad/s
	//  - Data[2]: rate of rotation around the z axis in rad/s
	//
	// If the event source is Magnetometer,
	//  - Data[0]: force of gravity along the x axis in m/s^2
	//  - Data[1]: force of gravity along the y axis in m/s^2
	//  - Data[2]: force of gravity along the z axis in m/s^2
	//
	Data []float64
}

// Manager multiplexes sensor event data from various sensor sources.
type Manager struct {
	m *manager // platform-specific implementation of the underlying manager
}

// Enable enables a sensor with the specified delay rate.
// If there are multiple sensors of type t on the device, Enable uses
// the default one.
// If there is no default sensor of type t on the device, an error returned.
// Valid sensor types supported by this package are Accelerometer,
// Gyroscope, Magnetometer and Altimeter.
func (m *Manager) Enable(t Type, delay time.Duration) error {
	if m.m == nil {
		m.m = new(manager)
		m.m.initialize()
	}
	if t < 0 || int(t) >= len(sensorNames) {
		return errors.New("sensor: unknown sensor type")
	}
	return m.m.enable(t, delay)
}

// Disable disables to feed the manager with the specified sensor.
func (m *Manager) Disable(t Type) error {
	if m.m == nil {
		m.m = new(manager)
		m.m.initialize()
	}
	if t < 0 || int(t) >= len(sensorNames) {
		return errors.New("sensor: unknown sensor type")
	}
	return m.m.disable(t)
}

// Read reads a series of events from the manager.
// It may read up to len(e) number of events, but will return
// less events if timeout occurs.
func (m *Manager) Read(e []Event) (n int, err error) {
	if m.m == nil {
		m.m = new(manager)
		m.m.initialize()
	}
	return m.m.read(e)
}

// Close stops the manager and frees the related resources.
// Once Close is called, Manager becomes invalid to use.
func (m *Manager) Close() error {
	if m.m == nil {
		return nil
	}
	return m.m.close()
}
