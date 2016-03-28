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

package ntor

import (
	"bytes"
	"testing"
)

// TestNewKeypair tests Curve25519/Elligator keypair generation.
func TestNewKeypair(t *testing.T) {
	// Test standard Curve25519 first.
	keypair, err := NewKeypair(false)
	if err != nil {
		t.Fatal("NewKeypair(false) failed:", err)
	}
	if keypair == nil {
		t.Fatal("NewKeypair(false) returned nil")
	}
	if keypair.HasElligator() {
		t.Fatal("NewKeypair(false) has a Elligator representative")
	}

	// Test Elligator generation.
	keypair, err = NewKeypair(true)
	if err != nil {
		t.Fatal("NewKeypair(true) failed:", err)
	}
	if keypair == nil {
		t.Fatal("NewKeypair(true) returned nil")
	}
	if !keypair.HasElligator() {
		t.Fatal("NewKeypair(true) mising an Elligator representative")
	}
}

// Test Client/Server handshake.
func TestHandshake(t *testing.T) {
	clientKeypair, err := NewKeypair(true)
	if err != nil {
		t.Fatal("Failed to generate client keypair:", err)
	}
	if clientKeypair == nil {
		t.Fatal("Client keypair is nil")
	}

	serverKeypair, err := NewKeypair(true)
	if err != nil {
		t.Fatal("Failed to generate server keypair:", err)
	}
	if serverKeypair == nil {
		t.Fatal("Server keypair is nil")
	}

	idKeypair, err := NewKeypair(false)
	if err != nil {
		t.Fatal("Failed to generate identity keypair:", err)
	}
	if idKeypair == nil {
		t.Fatal("Identity keypair is nil")
	}

	nodeID, err := NewNodeID([]byte("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13"))
	if err != nil {
		t.Fatal("Failed to load NodeId:", err)
	}

	// ServerHandshake
	clientPublic := clientKeypair.Representative().ToPublic()
	ok, serverSeed, serverAuth := ServerHandshake(clientPublic,
		serverKeypair, idKeypair, nodeID)
	if !ok {
		t.Fatal("ServerHandshake failed")
	}
	if serverSeed == nil {
		t.Fatal("ServerHandshake returned nil KEY_SEED")
	}
	if serverAuth == nil {
		t.Fatal("ServerHandshake returned nil AUTH")
	}

	// ClientHandshake
	ok, clientSeed, clientAuth := ClientHandshake(clientKeypair,
		serverKeypair.Public(), idKeypair.Public(), nodeID)
	if !ok {
		t.Fatal("ClientHandshake failed")
	}
	if clientSeed == nil {
		t.Fatal("ClientHandshake returned nil KEY_SEED")
	}
	if clientAuth == nil {
		t.Fatal("ClientHandshake returned nil AUTH")
	}

	// WARNING: Use a constant time comparison in actual code.
	if 0 != bytes.Compare(clientSeed.Bytes()[:], serverSeed.Bytes()[:]) {
		t.Fatal("KEY_SEED mismatched between client/server")
	}
	if 0 != bytes.Compare(clientAuth.Bytes()[:], serverAuth.Bytes()[:]) {
		t.Fatal("AUTH mismatched between client/server")
	}
}

// Benchmark Client/Server handshake.  The actual time taken that will be
// observed on either the Client or Server is half the reported time per
// operation since the benchmark does both sides.
func BenchmarkHandshake(b *testing.B) {
	// Generate the "long lasting" identity key and NodeId.
	idKeypair, err := NewKeypair(false)
	if err != nil || idKeypair == nil {
		b.Fatal("Failed to generate identity keypair")
	}
	nodeID, err := NewNodeID([]byte("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13"))
	if err != nil {
		b.Fatal("Failed to load NodeId:", err)
	}
	b.ResetTimer()

	// Start the actual benchmark.
	for i := 0; i < b.N; i++ {
		// Generate the keypairs.
		serverKeypair, err := NewKeypair(true)
		if err != nil || serverKeypair == nil {
			b.Fatal("Failed to generate server keypair")
		}

		clientKeypair, err := NewKeypair(true)
		if err != nil || clientKeypair == nil {
			b.Fatal("Failed to generate client keypair")
		}

		// Server handshake.
		clientPublic := clientKeypair.Representative().ToPublic()
		ok, serverSeed, serverAuth := ServerHandshake(clientPublic,
			serverKeypair, idKeypair, nodeID)
		if !ok || serverSeed == nil || serverAuth == nil {
			b.Fatal("ServerHandshake failed")
		}

		// Client handshake.
		serverPublic := serverKeypair.Representative().ToPublic()
		ok, clientSeed, clientAuth := ClientHandshake(clientKeypair,
			serverPublic, idKeypair.Public(), nodeID)
		if !ok || clientSeed == nil || clientAuth == nil {
			b.Fatal("ClientHandshake failed")
		}

		// Validate the authenticator.  Real code would pass the AUTH read off
		// the network as a slice to CompareAuth here.
		if !CompareAuth(clientAuth, serverAuth.Bytes()[:]) ||
			!CompareAuth(serverAuth, clientAuth.Bytes()[:]) {
			b.Fatal("AUTH mismatched between client/server")
		}
	}
}
