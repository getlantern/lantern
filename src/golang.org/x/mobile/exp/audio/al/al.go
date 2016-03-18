// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

// Package al provides OpenAL Soft bindings for Go.
//
// Calls are not safe for concurrent use.
//
// More information about OpenAL Soft is available at
// http://www.openal.org/documentation/openal-1.1-specification.pdf.
//
// In order to use this package on Linux desktop distros,
// you will need OpenAL library as an external dependency.
// On Ubuntu 14.04 'Trusty', you may have to install this library
// by running the command below.
//
// 		sudo apt-get install libopenal-dev
//
// When compiled for Android, this package uses OpenAL Soft. Please add its
// license file to the open source notices of your application.
// OpenAL Soft's license file could be found at
// http://repo.or.cz/w/openal-soft.git/blob/HEAD:/COPYING.
package al // import "golang.org/x/mobile/exp/audio/al"

// Capability represents OpenAL extension capabilities.
type Capability int32

// Enable enables a capability.
func Enable(c Capability) {
	alEnable(int32(c))
}

// Disable disables a capability.
func Disable(c Capability) {
	alDisable(int32(c))
}

// Enabled returns true if the specified capability is enabled.
func Enabled(c Capability) bool {
	return alIsEnabled(int32(c))
}

// Vector represents an vector in a Cartesian coordinate system.
type Vector [3]float32

// Orientation represents the angular position of an object in a
// right-handed Cartesian coordinate system.
// A cross product between the forward and up vector returns a vector
// that points to the right.
type Orientation struct {
	// Forward vector is the direction that the object is looking at.
	Forward Vector
	// Up vector represents the rotation of the object.
	Up Vector
}

func orientationFromSlice(v []float32) Orientation {
	return Orientation{
		Forward: Vector{v[0], v[1], v[2]},
		Up:      Vector{v[3], v[4], v[5]},
	}
}

func (v Orientation) slice() []float32 {
	return []float32{v.Forward[0], v.Forward[1], v.Forward[2], v.Up[0], v.Up[1], v.Up[2]}
}

// Geti returns the int32 value of the given parameter.
func Geti(param int) int32 {
	return alGetInteger(param)
}

// Getiv returns the int32 vector value of the given parameter.
func Getiv(param int, v []int32) {
	alGetIntegerv(param, v)
}

// Getf returns the float32 value of the given parameter.
func Getf(param int) float32 {
	return alGetFloat(param)
}

// Getfv returns the float32 vector value of the given parameter.
func Getfv(param int, v []float32) {
	alGetFloatv(param, v[:])
}

// Getb returns the bool value of the given parameter.
func Getb(param int) bool {
	return alGetBoolean(param)
}

// Getbv returns the bool vector value of the given parameter.
func Getbv(param int, v []bool) {
	alGetBooleanv(param, v)
}

// GetString returns the string value of the given parameter.
func GetString(param int) string {
	return alGetString(param)
}

// DistanceModel returns the distance model.
func DistanceModel() int32 {
	return Geti(paramDistanceModel)
}

// SetDistanceModel sets the distance model.
func SetDistanceModel(v int32) {
	alDistanceModel(v)
}

// DopplerFactor returns the doppler factor.
func DopplerFactor() float32 {
	return Getf(paramDopplerFactor)
}

// SetDopplerFactor sets the doppler factor.
func SetDopplerFactor(v float32) {
	alDopplerFactor(v)
}

// DopplerVelocity returns the doppler velocity.
func DopplerVelocity() float32 {
	return Getf(paramDopplerVelocity)
}

// SetDopplerVelocity sets the doppler velocity.
func SetDopplerVelocity(v float32) {
	alDopplerVelocity(v)
}

// SpeedOfSound is the speed of sound in meters per second (m/s).
func SpeedOfSound() float32 {
	return Getf(paramSpeedOfSound)
}

// SetSpeedOfSound sets the speed of sound, its unit should be meters per second (m/s).
func SetSpeedOfSound(v float32) {
	alSpeedOfSound(v)
}

// Vendor returns the vendor.
func Vendor() string {
	return GetString(paramVendor)
}

// Version returns the version string.
func Version() string {
	return GetString(paramVersion)
}

// Renderer returns the renderer information.
func Renderer() string {
	return GetString(paramRenderer)
}

// Extensions returns the enabled extensions.
func Extensions() string {
	return GetString(paramExtensions)
}

// Error returns the most recently generated error.
func Error() int32 {
	return alGetError()
}

// Source represents an individual sound source in 3D-space.
// They take PCM data, apply modifications and then submit them to
// be mixed according to their spatial location.
type Source uint32

// GenSources generates n new sources. These sources should be deleted
// once they are not in use.
func GenSources(n int) []Source {
	return alGenSources(n)
}

// PlaySources plays the sources.
func PlaySources(source ...Source) {
	alSourcePlayv(source)
}

// PauseSources pauses the sources.
func PauseSources(source ...Source) {
	alSourcePausev(source)
}

// StopSources stops the sources.
func StopSources(source ...Source) {
	alSourceStopv(source)
}

// RewindSources rewinds the sources to their beginning positions.
func RewindSources(source ...Source) {
	alSourceRewindv(source)
}

// DeleteSources deletes the sources.
func DeleteSources(source ...Source) {
	alDeleteSources(source)
}

// Gain returns the source gain.
func (s Source) Gain() float32 {
	return s.Getf(paramGain)
}

// SetGain sets the source gain.
func (s Source) SetGain(v float32) {
	s.Setf(paramGain, v)
}

// MinGain returns the source's minimum gain setting.
func (s Source) MinGain() float32 {
	return s.Getf(paramMinGain)
}

// SetMinGain sets the source's minimum gain setting.
func (s Source) SetMinGain(v float32) {
	s.Setf(paramMinGain, v)
}

// MaxGain returns the source's maximum gain setting.
func (s Source) MaxGain() float32 {
	return s.Getf(paramMaxGain)
}

// SetMaxGain sets the source's maximum gain setting.
func (s Source) SetMaxGain(v float32) {
	s.Setf(paramMaxGain, v)
}

// Position returns the position of the source.
func (s Source) Position() Vector {
	v := Vector{}
	s.Getfv(paramPosition, v[:])
	return v
}

// SetPosition sets the position of the source.
func (s Source) SetPosition(v Vector) {
	s.Setfv(paramPosition, v[:])
}

// Velocity returns the source's velocity.
func (s Source) Velocity() Vector {
	v := Vector{}
	s.Getfv(paramVelocity, v[:])
	return v
}

// SetVelocity sets the source's velocity.
func (s Source) SetVelocity(v Vector) {
	s.Setfv(paramVelocity, v[:])
}

// Orientation returns the orientation of the source.
func (s Source) Orientation() Orientation {
	v := make([]float32, 6)
	s.Getfv(paramOrientation, v)
	return orientationFromSlice(v)
}

// SetOrientation sets the orientation of the source.
func (s Source) SetOrientation(o Orientation) {
	s.Setfv(paramOrientation, o.slice())
}

// State returns the playing state of the source.
func (s Source) State() int32 {
	return s.Geti(paramSourceState)
}

// BuffersQueued returns the number of the queued buffers.
func (s Source) BuffersQueued() int32 {
	return s.Geti(paramBuffersQueued)
}

// BuffersProcessed returns the number of the processed buffers.
func (s Source) BuffersProcessed() int32 {
	return s.Geti(paramBuffersProcessed)
}

// OffsetSeconds returns the current playback position of the source in seconds.
func (s Source) OffsetSeconds() int32 {
	return s.Geti(paramSecOffset)
}

// OffsetSample returns the sample offset of the current playback position.
func (s Source) OffsetSample() int32 {
	return s.Geti(paramSampleOffset)
}

// OffsetByte returns the byte offset of the current playback position.
func (s Source) OffsetByte() int32 {
	return s.Geti(paramByteOffset)
}

// Geti returns the int32 value of the given parameter.
func (s Source) Geti(param int) int32 {
	return alGetSourcei(s, param)
}

// Getf returns the float32 value of the given parameter.
func (s Source) Getf(param int) float32 {
	return alGetSourcef(s, param)
}

// Getfv returns the float32 vector value of the given parameter.
func (s Source) Getfv(param int, v []float32) {
	alGetSourcefv(s, param, v)
}

// Seti sets an int32 value for the given parameter.
func (s Source) Seti(param int, v int32) {
	alSourcei(s, param, v)
}

// Setf sets a float32 value for the given parameter.
func (s Source) Setf(param int, v float32) {
	alSourcef(s, param, v)
}

// Setfv sets a float32 vector value for the given parameter.
func (s Source) Setfv(param int, v []float32) {
	alSourcefv(s, param, v)
}

// QueueBuffers adds the buffers to the buffer queue.
func (s Source) QueueBuffers(buffer ...Buffer) {
	alSourceQueueBuffers(s, buffer)
}

// UnqueueBuffers removes the specified buffers from the buffer queue.
func (s Source) UnqueueBuffers(buffer ...Buffer) {
	alSourceUnqueueBuffers(s, buffer)
}

// ListenerGain returns the total gain applied to the final mix.
func ListenerGain() float32 {
	return GetListenerf(paramGain)
}

// ListenerPosition returns the position of the listener.
func ListenerPosition() Vector {
	v := Vector{}
	GetListenerfv(paramPosition, v[:])
	return v
}

// ListenerVelocity returns the velocity of the listener.
func ListenerVelocity() Vector {
	v := Vector{}
	GetListenerfv(paramVelocity, v[:])
	return v
}

// ListenerOrientation returns the orientation of the listener.
func ListenerOrientation() Orientation {
	v := make([]float32, 6)
	GetListenerfv(paramOrientation, v)
	return orientationFromSlice(v)
}

// SetListenerGain sets the total gain that will be applied to the final mix.
func SetListenerGain(v float32) {
	SetListenerf(paramGain, v)
}

// SetListenerPosition sets the position of the listener.
func SetListenerPosition(v Vector) {
	SetListenerfv(paramPosition, v[:])
}

// SetListenerVelocity sets the velocity of the listener.
func SetListenerVelocity(v Vector) {
	SetListenerfv(paramVelocity, v[:])
}

// SetListenerOrientation sets the orientation of the listener.
func SetListenerOrientation(v Orientation) {
	SetListenerfv(paramOrientation, v.slice())
}

// GetListenerf returns the float32 value of the listener parameter.
func GetListenerf(param int) float32 {
	return alGetListenerf(param)
}

// GetListenerfv returns the float32 vector value of the listener parameter.
func GetListenerfv(param int, v []float32) {
	alGetListenerfv(param, v)
}

// GetListenerf sets the float32 value for the listener parameter.
func SetListenerf(param int, v float32) {
	alListenerf(param, v)
}

// GetListenerf sets the float32 vector value of the listener parameter.
func SetListenerfv(param int, v []float32) {
	alListenerfv(param, v)
}

// A buffer represents a chunk of PCM audio data that could be buffered to an audio
// source. A single buffer could be shared between multiple sources.
type Buffer uint32

// GenBuffers generates n new buffers. The generated buffers should be deleted
// once they are no longer in use.
func GenBuffers(n int) []Buffer {
	return alGenBuffers(n)
}

// DeleteBuffers deletes the buffers.
func DeleteBuffers(buffer ...Buffer) {
	alDeleteBuffers(buffer)
}

// Geti returns the int32 value of the given parameter.
func (b Buffer) Geti(param int) int32 {
	return b.Geti(param)
}

// Frequency returns the frequency of the buffer data in Hertz (Hz).
func (b Buffer) Frequency() int32 {
	return b.Geti(paramFreq)
}

// Bits return the number of bits used to represent a sample.
func (b Buffer) Bits() int32 {
	return b.Geti(paramBits)
}

// Channels return the number of the audio channels.
func (b Buffer) Channels() int32 {
	return b.Geti(paramChannels)
}

// Size returns the size of the data.
func (b Buffer) Size() int32 {
	return b.Geti(paramSize)
}

// BufferData buffers PCM data to the current buffer.
func (b Buffer) BufferData(format uint32, data []byte, freq int32) {
	alBufferData(b, format, data, freq)
}

// Valid returns true if the buffer exists and is valid.
func (b Buffer) Valid() bool {
	return alIsBuffer(b)
}
