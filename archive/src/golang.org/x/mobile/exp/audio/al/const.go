// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

package al

// Error returns one of these error codes.
const (
	InvalidName      = 0xA001
	InvalidEnum      = 0xA002
	InvalidValue     = 0xA003
	InvalidOperation = 0xA004
	OutOfMemory      = 0xA005
)

// Distance models.
const (
	InverseDistance         = 0xD001
	InverseDistanceClamped  = 0xD002
	LinearDistance          = 0xD003
	LinearDistanceClamped   = 0xD004
	ExponentDistance        = 0xD005
	ExponentDistanceClamped = 0xD006
)

// Global parameters.
const (
	paramDistanceModel   = 0xD000
	paramDopplerFactor   = 0xC000
	paramDopplerVelocity = 0xC001
	paramSpeedOfSound    = 0xC003
	paramVendor          = 0xB001
	paramVersion         = 0xB002
	paramRenderer        = 0xB003
	paramExtensions      = 0xB004
)

// Source and listener parameters.
const (
	paramGain             = 0x100A
	paramPosition         = 0x1004
	paramVelocity         = 0x1006
	paramOrientation      = 0x100F
	paramMinGain          = 0x100D
	paramMaxGain          = 0x100E
	paramSourceState      = 0x1010
	paramBuffersQueued    = 0x1015
	paramBuffersProcessed = 0x1016
	paramSecOffset        = 0x1024
	paramSampleOffset     = 0x1025
	paramByteOffset       = 0x1026
)

// A source could be in the state of initial, playing, paused or stopped.
const (
	Initial = 0x1011
	Playing = 0x1012
	Paused  = 0x1013
	Stopped = 0x1014
)

// Buffer parameters.
const (
	paramFreq     = 0x2001
	paramBits     = 0x2002
	paramChannels = 0x2003
	paramSize     = 0x2004
)

// Audio formats. Buffer.BufferData accepts one of these formats as the data format.
const (
	FormatMono8    = 0x1100
	FormatMono16   = 0x1101
	FormatStereo8  = 0x1102
	FormatStereo16 = 0x1103
)

// CapabilityDistanceModel represents the capability of specifying a different distance
// model for each source.
const CapabilityDistanceModel = Capability(0x200)
