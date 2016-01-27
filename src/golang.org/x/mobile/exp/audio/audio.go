// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux

// Package audio provides a basic audio player.
//
// In order to use this package on Linux desktop distros,
// you will need OpenAL library as an external dependency.
// On Ubuntu 14.04 'Trusty', you may have to install this library
// by running the command below.
//
// 		sudo apt-get install libopenal-dev
//
// When compiled for Android, this package uses OpenAL Soft as a backend.
// Please add its license file to the open source notices of your
// application.
// OpenAL Soft's license file could be found at
// http://repo.or.cz/w/openal-soft.git/blob/HEAD:/COPYING.
package audio // import "golang.org/x/mobile/exp/audio"

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"sync"
	"time"

	"golang.org/x/mobile/exp/audio/al"
)

// ReadSeekCloser is an io.ReadSeeker and io.Closer.
type ReadSeekCloser interface {
	io.ReadSeeker
	io.Closer
}

// Format represents a PCM data format.
type Format int

const (
	Mono8 Format = iota + 1
	Mono16
	Stereo8
	Stereo16
)

func (f Format) String() string { return formatStrings[f] }

// formatBytes is the product of bytes per sample and number of channels.
var formatBytes = [...]int64{
	Mono8:    1,
	Mono16:   2,
	Stereo8:  2,
	Stereo16: 4,
}

var formatCodes = [...]uint32{
	Mono8:    al.FormatMono8,
	Mono16:   al.FormatMono16,
	Stereo8:  al.FormatStereo8,
	Stereo16: al.FormatStereo16,
}

var formatStrings = [...]string{
	0:        "unknown",
	Mono8:    "mono8",
	Mono16:   "mono16",
	Stereo8:  "stereo8",
	Stereo16: "stereo16",
}

// State indicates the current playing state of the player.
type State int

const (
	Unknown State = iota
	Initial
	Playing
	Paused
	Stopped
)

func (s State) String() string { return stateStrings[s] }

var stateStrings = [...]string{
	Unknown: "unknown",
	Initial: "initial",
	Playing: "playing",
	Paused:  "paused",
	Stopped: "stopped",
}

var codeToState = map[int32]State{
	0:          Unknown,
	al.Initial: Initial,
	al.Playing: Playing,
	al.Paused:  Paused,
	al.Stopped: Stopped,
}

type track struct {
	format           Format
	samplesPerSecond int64
	src              ReadSeekCloser

	// hasHeader represents whether the audio source contains
	// a PCM header. If true, the audio data starts 44 bytes
	// later in the source.
	hasHeader bool
}

// Player is a basic audio player that plays PCM data.
// Operations on a nil *Player are no-op, a nil *Player can
// be used for testing purposes.
type Player struct {
	t      *track
	source al.Source

	mu        sync.Mutex
	prep      bool
	bufs      []al.Buffer // buffers are created and queued to source during prepare.
	sizeBytes int64       // size of the audio source
}

// NewPlayer returns a new Player.
// It initializes the underlying audio devices and the related resources.
// If zero values are provided for format and sample rate values, the player
// determines them from the source's WAV header.
// An error is returned if the format and sample rate can't be determined.
//
// The audio package is only designed for small audio sources.
func NewPlayer(src ReadSeekCloser, format Format, samplesPerSecond int64) (*Player, error) {
	if err := al.OpenDevice(); err != nil {
		return nil, err
	}
	s := al.GenSources(1)
	if code := al.Error(); code != 0 {
		return nil, fmt.Errorf("audio: cannot generate an audio source [err=%x]", code)
	}
	p := &Player{
		t:      &track{format: format, src: src, samplesPerSecond: samplesPerSecond},
		source: s[0],
	}
	if err := p.discoverHeader(); err != nil {
		return nil, err
	}
	if p.t.format == 0 {
		return nil, errors.New("audio: cannot determine the format")
	}
	if p.t.samplesPerSecond == 0 {
		return nil, errors.New("audio: cannot determine the sample rate")
	}
	return p, nil
}

// headerSize is the size of WAV headers.
// See http://www.topherlee.com/software/pcm-tut-wavformat.html.
const headerSize = 44

var (
	riffHeader = []byte("RIFF")
	waveHeader = []byte("WAVE")
)

func (p *Player) discoverHeader() error {
	buf := make([]byte, headerSize)
	if n, _ := io.ReadFull(p.t.src, buf); n != headerSize {
		// No header present or read error.
		return nil
	}
	if !(bytes.Equal(buf[0:4], riffHeader) && bytes.Equal(buf[8:12], waveHeader)) {
		return nil
	}
	p.t.hasHeader = true
	var format Format
	switch channels, depth := buf[22], buf[34]; {
	case channels == 1 && depth == 8:
		format = Mono8
	case channels == 1 && depth == 16:
		format = Mono16
	case channels == 2 && depth == 8:
		format = Stereo8
	case channels == 2 && depth == 16:
		format = Stereo16
	default:
		return fmt.Errorf("audio: unsupported format; num of channels=%d, bit rate=%d", channels, depth)
	}
	if p.t.format == 0 {
		p.t.format = format
	}
	if p.t.format != format {
		return fmt.Errorf("audio: given format %v does not match header %v", p.t.format, format)
	}
	sampleRate := int64(buf[24]) | int64(buf[25])<<8 | int64(buf[26])<<16 | int64(buf[27]<<24)
	if p.t.samplesPerSecond == 0 {
		p.t.samplesPerSecond = sampleRate
	}
	if p.t.samplesPerSecond != sampleRate {
		return fmt.Errorf("audio: given sample rate %v does not match header", p.t.samplesPerSecond, sampleRate)
	}
	return nil
}

func (p *Player) prepare(offset int64, force bool) error {
	p.mu.Lock()
	if !force && p.prep {
		p.mu.Unlock()
		return nil
	}
	p.mu.Unlock()

	if p.t.hasHeader {
		offset += headerSize
	}
	if _, err := p.t.src.Seek(offset, 0); err != nil {
		return err
	}
	var bufs []al.Buffer
	// TODO(jbd): Limit the number of buffers in use, unqueue and reuse
	// the existing buffers as buffers are processed.
	buf := make([]byte, 128*1024)
	size := offset
	for {
		n, err := p.t.src.Read(buf)
		if n > 0 {
			size += int64(n)
			b := al.GenBuffers(1)
			b[0].BufferData(formatCodes[p.t.format], buf[:n], int32(p.t.samplesPerSecond))
			bufs = append(bufs, b[0])
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}

	p.mu.Lock()
	if len(p.bufs) > 0 {
		p.source.UnqueueBuffers(p.bufs...)
		al.DeleteBuffers(p.bufs...)
	}
	p.sizeBytes = size
	p.bufs = bufs
	p.prep = true
	if len(bufs) > 0 {
		p.source.QueueBuffers(bufs...)
	}
	p.mu.Unlock()
	return nil
}

// Play buffers the source audio to the audio device and starts
// to play the source.
// If the player paused or stopped, it reuses the previously buffered
// resources to keep playing from the time it has paused or stopped.
func (p *Player) Play() error {
	if p == nil {
		return nil
	}
	// Prepares if the track hasn't been buffered before.
	if err := p.prepare(0, false); err != nil {
		return err
	}
	al.PlaySources(p.source)
	return lastErr()
}

// Pause pauses the player.
func (p *Player) Pause() error {
	if p == nil {
		return nil
	}
	al.PauseSources(p.source)
	return lastErr()
}

// Stop stops the player.
func (p *Player) Stop() error {
	if p == nil {
		return nil
	}
	al.StopSources(p.source)
	return lastErr()
}

// Seek moves the play head to the given offset relative to the start of the source.
func (p *Player) Seek(offset time.Duration) error {
	if p == nil {
		return nil
	}
	if err := p.Stop(); err != nil {
		return err
	}
	size := durToByteOffset(p.t, offset)
	if err := p.prepare(size, true); err != nil {
		return err
	}
	al.PlaySources(p.source)
	return lastErr()
}

// Current returns the current playback position of the audio that is being played.
func (p *Player) Current() time.Duration {
	if p == nil {
		return 0
	}
	// TODO(jbd): Current never returns the Total when the playing is finished.
	// OpenAL may be returning the last buffer's start point as an OffsetByte.
	return byteOffsetToDur(p.t, int64(p.source.OffsetByte()))
}

// Total returns the total duration of the audio source.
func (p *Player) Total() time.Duration {
	if p == nil {
		return 0
	}
	// Prepare is required to determine the length of the source.
	// We need to read the entire source to calculate the length.
	p.prepare(0, false)
	return byteOffsetToDur(p.t, p.sizeBytes)
}

// Volume returns the current player volume. The range of the volume is [0, 1].
func (p *Player) Volume() float64 {
	if p == nil {
		return 0
	}
	return float64(p.source.Gain())
}

// SetVolume sets the volume of the player. The range of the volume is [0, 1].
func (p *Player) SetVolume(vol float64) {
	if p == nil {
		return
	}
	p.source.SetGain(float32(vol))
}

// State returns the player's current state.
func (p *Player) State() State {
	if p == nil {
		return Unknown
	}
	return codeToState[p.source.State()]
}

// Close closes the device and frees the underlying resources
// used by the player.
// It should be called as soon as the player is not in-use anymore.
func (p *Player) Close() error {
	if p == nil {
		return nil
	}
	if p.source != 0 {
		al.DeleteSources(p.source)
	}
	p.mu.Lock()
	if len(p.bufs) > 0 {
		al.DeleteBuffers(p.bufs...)
	}
	p.mu.Unlock()
	p.t.src.Close()
	return nil
}

func byteOffsetToDur(t *track, offset int64) time.Duration {
	return time.Duration(offset * formatBytes[t.format] * int64(time.Second) / t.samplesPerSecond)
}

func durToByteOffset(t *track, dur time.Duration) int64 {
	return int64(dur) * t.samplesPerSecond / (formatBytes[t.format] * int64(time.Second))
}

// lastErr returns the last error or nil if the last operation
// has been succesful.
func lastErr() error {
	if code := al.Error(); code != 0 {
		return fmt.Errorf("audio: openal failed with %x", code)
	}
	return nil
}

// TODO(jbd): Close the device.
