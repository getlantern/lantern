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

package uniformdh

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"testing"
)

const (
	xPrivStr = "6f592d676f536874746f20686e6b776f" +
		"20736874206561676574202e6f592d67" +
		"6f536874746f20687369742065686720" +
		"74612e655920676f532d746f6f686874" +
		"6920207368742065656b20796e612064" +
		"7567726169646e616f20206668742065" +
		"61676574202e61507473202c72707365" +
		"6e652c746620747572752c6561206c6c" +
		"612065726f20656e6920206e6f592d67" +
		"6f536874746f2e68482020656e6b776f" +
		"2073687772652065687420656c4f2064" +
		"6e4f736562206f72656b74207268756f"

	xPubStr = "76a3d17d5c55b03e865fa3e8267990a7" +
		"24baa24b0bdd0cc4af93be8de30be120" +
		"d5533c91bf63ef923b02edcb84b74438" +
		"3f7de232cca6eb46d07cad83dcaa317f" +
		"becbc68ca13e2c4019e6a36531067450" +
		"04aecc0be1dff0a78733fb0e7d5cb7c4" +
		"97cab77b1331bf347e5f3a7847aa0bc0" +
		"f4bc64146b48407fed7b931d16972d25" +
		"fb4da5e6dc074ce2a58daa8de7624247" +
		"cdf2ebe4e4dfec6d5989aac778c87559" +
		"d3213d6040d4111ce3a2acae19f9ee15" +
		"32509e037f69b252fdc30243cbbce9d0"

	yPrivStr = "736562206f72656b74207268756f6867" +
		"6f2020666c6f2c646120646e77206568" +
		"657254206568207968736c61206c7262" +
		"6165206b68746f726775206867616961" +
		"2e6e482020656e6b776f207368777265" +
		"2065685479656820766120657274646f" +
		"652072616874732766206569646c2c73" +
		"6120646e772065686572542065682079" +
		"74736c69206c72746165206468746d65" +
		"202c6e612064687720796f6e6f20656e" +
		"63206e61622068656c6f206468546d65" +
		"61202073685479657420657264610a2e"

	yPubStr = "d04e156e554c37ffd7aba749df662350" +
		"1e4ff4466cb12be055617c1a36872237" +
		"36d2c3fdce9ee0f9b27774350849112a" +
		"a5aeb1f126811c9c2f3a9cb13d2f0c3a" +
		"7e6fa2d3bf71baf50d839171534f227e" +
		"fbb2ce4227a38c25abdc5ba7fc430111" +
		"3a2cb2069c9b305faac4b72bf21fec71" +
		"578a9c369bcac84e1a7dcf0754e342f5" +
		"bc8fe4917441b88254435e2abaf297e9" +
		"3e1e57968672d45bd7d4c8ba1bc3d314" +
		"889b5bc3d3e4ea33d4f2dfdd34e5e5a7" +
		"2ff24ee46316d4757dad09366a0b66b3"

	ssStr = "78afaf5f457f1fdb832bebc397644a33" +
		"038be9dba10ca2ce4a076f327f3a0ce3" +
		"151d477b869ee7ac467755292ad8a77d" +
		"b9bd87ffbbc39955bcfb03b1583888c8" +
		"fd037834ff3f401d463c10f899aa6378" +
		"445140b7f8386a7d509e7b9db19b677f" +
		"062a7a1a4e1509604d7a0839ccd5da61" +
		"73e10afd9eab6dda74539d60493ca37f" +
		"a5c98cd9640b409cd8bb3be2bc5136fd" +
		"42e764fc3f3c0ddb8db3d87abcf2e659" +
		"8d2b101bef7a56f50ebc658f9df1287d" +
		"a81359543e77e4a4cfa7598a4152e4c0"
)

var xPriv, xPub, yPriv, yPub, ss []byte

// TestGenerateKeyOdd tests creating a UniformDH keypair with a odd private
// key.
func TestGenerateKeyOdd(t *testing.T) {
	xX, err := generateKey(xPriv)
	if err != nil {
		t.Fatal("generateKey(xPriv) failed:", err)
	}

	xPubGen, err := xX.PublicKey.Bytes()
	if err != nil {
		t.Fatal("xX.PublicKey.Bytes() failed:", err)
	}
	if 0 != bytes.Compare(xPubGen, xPub) {
		t.Fatal("Generated public key does not match known answer")
	}
}

// TestGenerateKeyEven tests creating a UniformDH keypair with a even private
// key.
func TestGenerateKeyEven(t *testing.T) {
	yY, err := generateKey(yPriv)
	if err != nil {
		t.Fatal("generateKey(yPriv) failed:", err)
	}

	yPubGen, err := yY.PublicKey.Bytes()
	if err != nil {
		t.Fatal("yY.PublicKey.Bytes() failed:", err)
	}
	if 0 != bytes.Compare(yPubGen, yPub) {
		t.Fatal("Generated public key does not match known answer")
	}
}

// TestHandshake tests conductiong a UniformDH handshake with know values.
func TestHandshake(t *testing.T) {
	xX, err := generateKey(xPriv)
	if err != nil {
		t.Fatal("generateKey(xPriv) failed:", err)
	}
	yY, err := generateKey(yPriv)
	if err != nil {
		t.Fatal("generateKey(yPriv) failed:", err)
	}

	xY, err := Handshake(xX, &yY.PublicKey)
	if err != nil {
		t.Fatal("Handshake(xX, yY.PublicKey) failed:", err)
	}
	yX, err := Handshake(yY, &xX.PublicKey)
	if err != nil {
		t.Fatal("Handshake(yY, xX.PublicKey) failed:", err)
	}

	if 0 != bytes.Compare(xY, yX) {
		t.Fatal("Generated shared secrets do not match between peers")
	}
	if 0 != bytes.Compare(xY, ss) {
		t.Fatal("Generated shared secret does not match known value")
	}
}

// Benchmark UniformDH key generation + exchange.  THe actual time taken per
// peer is half of the reported time as this does 2 key generation an
// handshake operations.
func BenchmarkHandshake(b *testing.B) {
	for i := 0; i < b.N; i++ {
		xX, err := GenerateKey(rand.Reader)
		if err != nil {
			b.Fatal("Failed to generate xX keypair", err)
		}

		yY, err := GenerateKey(rand.Reader)
		if err != nil {
			b.Fatal("Failed to generate yY keypair", err)
		}

		xY, err := Handshake(xX, &yY.PublicKey)
		if err != nil {
			b.Fatal("Handshake(xX, yY.PublicKey) failed:", err)
		}
		yX, err := Handshake(yY, &xX.PublicKey)
		if err != nil {
			b.Fatal("Handshake(yY, xX.PublicKey) failed:", err)
		}

		_ = xY
		_ = yX
	}
}

func init() {
	// Load the test vectors into byte slices.
	var err error
	xPriv, err = hex.DecodeString(xPrivStr)
	if err != nil {
		panic("hex.DecodeString(xPrivStr) failed")
	}
	xPub, err = hex.DecodeString(xPubStr)
	if err != nil {
		panic("hex.DecodeString(xPubStr) failed")
	}
	yPriv, err = hex.DecodeString(yPrivStr)
	if err != nil {
		panic("hex.DecodeString(yPrivStr) failed")
	}
	yPub, err = hex.DecodeString(yPubStr)
	if err != nil {
		panic("hex.DecodeString(yPubStr) failed")
	}
	ss, err = hex.DecodeString(ssStr)
	if err != nil {
		panic("hex.DecodeString(ssStr) failed")
	}
}
