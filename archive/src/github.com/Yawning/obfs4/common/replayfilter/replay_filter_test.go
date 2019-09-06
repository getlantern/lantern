/*
 * Copyright (c) 2014, Yawning Angel <yawning at torproject dot org>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

package replayfilter

import (
	"testing"
	"time"
)

func TestReplayFilter(t *testing.T) {
	ttl := 10 * time.Second

	f, err := New(ttl)
	if err != nil {
		t.Fatal("newReplayFilter failed:", err)
	}

	buf := []byte("This is a test of the Emergency Broadcast System.")
	now := time.Now()

	// testAndSet into empty filter, returns false (not present).
	set := f.TestAndSet(now, buf)
	if set {
		t.Fatal("TestAndSet empty filter returned true")
	}

	// testAndSet into filter containing entry, should return true(present).
	set = f.TestAndSet(now, buf)
	if !set {
		t.Fatal("testAndSet populated filter (replayed) returned false")
	}

	buf2 := []byte("This concludes this test of the Emergency Broadcast System.")
	now = now.Add(ttl)

	// testAndSet with time advanced.
	set = f.TestAndSet(now, buf2)
	if set {
		t.Fatal("testAndSet populated filter, 2nd entry returned true")
	}
	set = f.TestAndSet(now, buf2)
	if !set {
		t.Fatal("testAndSet populated filter, 2nd entry (replayed) returned false")
	}

	// Ensure that the first entry has been removed by compact.
	set = f.TestAndSet(now, buf)
	if set {
		t.Fatal("testAndSet populated filter, compact check returned true")
	}

	// Ensure that the filter gets reaped if the clock jumps backwards.
	now = time.Time{}
	set = f.TestAndSet(now, buf)
	if set {
		t.Fatal("testAndSet populated filter, backward time jump returned true")
	}
	if len(f.filter) != 1 {
		t.Fatal("filter map has a unexpected number of entries:", len(f.filter))
	}
	if f.fifo.Len() != 1 {
		t.Fatal("filter fifo has a unexpected number of entries:", f.fifo.Len())
	}

	// Ensure that the entry is properly added after reaping.
	set = f.TestAndSet(now, buf)
	if !set {
		t.Fatal("testAndSet populated filter, post-backward clock jump (replayed) returned false")
	}
}
