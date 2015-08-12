// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux,!android

package audio

import (
	"testing"
	"time"
)

func TestNoOp(t *testing.T) {
	var p *Player
	if err := p.Play(); err != nil {
		t.Errorf("no-op player failed to play: %v", err)
	}
	if err := p.Pause(); err != nil {
		t.Errorf("no-op player failed to pause: %v", err)
	}
	if err := p.Stop(); err != nil {
		t.Errorf("no-op player failed to stop: %v", err)
	}
	if c := p.Current(); c != 0 {
		t.Errorf("no-op player returns a non-zero playback position: %v", c)
	}
	if tot := p.Total(); tot != 0 {
		t.Errorf("no-op player returns a non-zero total: %v", tot)
	}
	if vol := p.Volume(); vol != 0 {
		t.Errorf("no-op player returns a non-zero volume: %v", vol)
	}
	if s := p.State(); s != Unknown {
		t.Errorf("playing state: %v", s)
	}
	p.SetVolume(0.1)
	p.Seek(1 * time.Second)
	p.Close()
}
