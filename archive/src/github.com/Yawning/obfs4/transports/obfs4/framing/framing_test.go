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

package framing

import (
	"bytes"
	"crypto/rand"
	"testing"
)

func generateRandomKey() []byte {
	key := make([]byte, KeyLength)

	_, err := rand.Read(key)
	if err != nil {
		panic(err)
	}

	return key
}

func newEncoder(t *testing.T) *Encoder {
	// Generate a key to use.
	key := generateRandomKey()

	encoder := NewEncoder(key)
	if encoder == nil {
		t.Fatalf("NewEncoder returned nil")
	}

	return encoder
}

// TestNewEncoder tests the Encoder ctor.
func TestNewEncoder(t *testing.T) {
	encoder := newEncoder(t)
	_ = encoder
}

// TestEncoder_Encode tests Encoder.Encode.
func TestEncoder_Encode(t *testing.T) {
	encoder := newEncoder(t)

	buf := make([]byte, MaximumFramePayloadLength)
	_, _ = rand.Read(buf) // YOLO
	for i := 0; i <= MaximumFramePayloadLength; i++ {
		var frame [MaximumSegmentLength]byte
		n, err := encoder.Encode(frame[:], buf[0:i])
		if err != nil {
			t.Fatalf("Encoder.encode([%d]byte), failed: %s", i, err)
		}
		if n != i+FrameOverhead {
			t.Fatalf("Unexpected encoded framesize: %d, expecting %d", n, i+
				FrameOverhead)
		}
	}
}

// TestEncoder_Encode_Oversize tests oversized frame rejection.
func TestEncoder_Encode_Oversize(t *testing.T) {
	encoder := newEncoder(t)

	var frame [MaximumSegmentLength]byte
	var buf [MaximumFramePayloadLength + 1]byte
	_, _ = rand.Read(buf[:]) // YOLO
	_, err := encoder.Encode(frame[:], buf[:])
	if _, ok := err.(InvalidPayloadLengthError); !ok {
		t.Error("Encoder.encode() returned unexpected error:", err)
	}
}

// TestNewDecoder tests the Decoder ctor.
func TestNewDecoder(t *testing.T) {
	key := generateRandomKey()
	decoder := NewDecoder(key)
	if decoder == nil {
		t.Fatalf("NewDecoder returned nil")
	}
}

// TestDecoder_Decode tests Decoder.Decode.
func TestDecoder_Decode(t *testing.T) {
	key := generateRandomKey()

	encoder := NewEncoder(key)
	decoder := NewDecoder(key)

	var buf [MaximumFramePayloadLength]byte
	_, _ = rand.Read(buf[:]) // YOLO
	for i := 0; i <= MaximumFramePayloadLength; i++ {
		var frame [MaximumSegmentLength]byte
		encLen, err := encoder.Encode(frame[:], buf[0:i])
		if err != nil {
			t.Fatalf("Encoder.encode([%d]byte), failed: %s", i, err)
		}
		if encLen != i+FrameOverhead {
			t.Fatalf("Unexpected encoded framesize: %d, expecting %d", encLen,
				i+FrameOverhead)
		}

		var decoded [MaximumFramePayloadLength]byte

		decLen, err := decoder.Decode(decoded[:], bytes.NewBuffer(frame[:encLen]))
		if err != nil {
			t.Fatalf("Decoder.decode([%d]byte), failed: %s", i, err)
		}
		if decLen != i {
			t.Fatalf("Unexpected decoded framesize: %d, expecting %d",
				decLen, i)
		}

		if 0 != bytes.Compare(decoded[:decLen], buf[:i]) {
			t.Fatalf("Frame %d does not match encoder input", i)
		}
	}
}

// BencharkEncoder_Encode benchmarks Encoder.Encode processing 1 MiB
// of payload.
func BenchmarkEncoder_Encode(b *testing.B) {
	var chopBuf [MaximumFramePayloadLength]byte
	var frame [MaximumSegmentLength]byte
	payload := make([]byte, 1024*1024)
	encoder := NewEncoder(generateRandomKey())
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		transfered := 0
		buffer := bytes.NewBuffer(payload)
		for 0 < buffer.Len() {
			n, err := buffer.Read(chopBuf[:])
			if err != nil {
				b.Fatal("buffer.Read() failed:", err)
			}

			n, err = encoder.Encode(frame[:], chopBuf[:n])
			transfered += n - FrameOverhead
		}
		if transfered != len(payload) {
			b.Fatalf("Transfered length mismatch: %d != %d", transfered,
				len(payload))
		}
	}
}
