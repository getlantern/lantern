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

// Package uniformdh implements the Tor Project's UniformDH key exchange
// mechanism as defined in the obfs3 protocol specification.  This
// implementation is suitable for obfuscation but MUST NOT BE USED when strong
// security is required as it is not constant time.
package uniformdh

import (
	"fmt"
	"io"
	"math/big"
)

const (
	// Size is the size of a UniformDH key or shared secret in bytes.
	Size = 1536 / 8

	// modpStr is the RFC3526 1536-bit MODP Group (Group 5).
	modpStr = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1" +
		"29024E088A67CC74020BBEA63B139B22514A08798E3404DD" +
		"EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245" +
		"E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED" +
		"EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D" +
		"C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F" +
		"83655D23DCA3AD961C62F356208552BB9ED529077096966D" +
		"670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF"

	g = 2
)

var modpGroup *big.Int
var gen *big.Int

// A PrivateKey represents a UniformDH private key.
type PrivateKey struct {
	PublicKey
	privateKey *big.Int
}

// A PublicKey represents a UniformDH public key.
type PublicKey struct {
	bytes     []byte
	publicKey *big.Int
}

// Bytes returns the byte representation of a PublicKey.
func (pub *PublicKey) Bytes() (pubBytes []byte, err error) {
	if len(pub.bytes) != Size || pub.bytes == nil {
		return nil, fmt.Errorf("public key is not initialized")
	}
	pubBytes = make([]byte, Size)
	copy(pubBytes, pub.bytes)

	return
}

// SetBytes sets the PublicKey from a byte slice.
func (pub *PublicKey) SetBytes(pubBytes []byte) error {
	if len(pubBytes) != Size {
		return fmt.Errorf("public key length %d is not %d", len(pubBytes), Size)
	}
	pub.bytes = make([]byte, Size)
	copy(pub.bytes, pubBytes)
	pub.publicKey = new(big.Int).SetBytes(pub.bytes)

	return nil
}

// GenerateKey generates a UniformDH keypair using the random source random.
func GenerateKey(random io.Reader) (priv *PrivateKey, err error) {
	privBytes := make([]byte, Size)
	if _, err = io.ReadFull(random, privBytes); err != nil {
		return
	}
	priv, err = generateKey(privBytes)

	return
}

func generateKey(privBytes []byte) (priv *PrivateKey, err error) {
	// This function does all of the actual heavy lifting of creating a public
	// key from a raw 192 byte private key.  It is split so that the KAT tests
	// can be written easily, and not exposed since non-ephemeral keys are a
	// terrible idea.

	if len(privBytes) != Size {
		return nil, fmt.Errorf("invalid private key size %d", len(privBytes))
	}

	// To pick a private UniformDH key, we pick a random 1536-bit number,
	// and make it even by setting its low bit to 0
	privBn := new(big.Int).SetBytes(privBytes)
	wasEven := privBn.Bit(0) == 0
	privBn = privBn.SetBit(privBn, 0, 0)

	// Let x be that private key, and X = g^x (mod p).
	pubBn := new(big.Int).Exp(gen, privBn, modpGroup)
	pubAlt := new(big.Int).Sub(modpGroup, pubBn)

	// When someone sends her public key to the other party, she randomly
	// decides whether to send X or p-X.  Use the lowest most bit of the
	// private key here as the random coin flip since it is masked out and not
	// used.
	//
	// Note: The spec doesn't explicitly specify it, but here we prepend zeros
	// to the key so that it is always exactly Size bytes.
	pubBytes := make([]byte, Size)
	if wasEven {
		err = prependZeroBytes(pubBytes, pubBn.Bytes())
	} else {
		err = prependZeroBytes(pubBytes, pubAlt.Bytes())
	}
	if err != nil {
		return
	}

	priv = new(PrivateKey)
	priv.PublicKey.bytes = pubBytes
	priv.PublicKey.publicKey = pubBn
	priv.privateKey = privBn

	return
}

// Handshake generates a shared secret given a PrivateKey and PublicKey.
func Handshake(privateKey *PrivateKey, publicKey *PublicKey) (sharedSecret []byte, err error) {
	// When a party wants to calculate the shared secret, she raises the
	// foreign public key to her private key.
	secretBn := new(big.Int).Exp(publicKey.publicKey, privateKey.privateKey, modpGroup)
	sharedSecret = make([]byte, Size)
	err = prependZeroBytes(sharedSecret, secretBn.Bytes())

	return
}

func prependZeroBytes(dst, src []byte) error {
	zeros := len(dst) - len(src)
	if zeros < 0 {
		return fmt.Errorf("src length is greater than destination: %d", zeros)
	}
	for i := 0; i < zeros; i++ {
		dst[i] = 0
	}
	copy(dst[zeros:], src)

	return nil
}

func init() {
	// Load the MODP group and the generator.
	var ok bool
	modpGroup, ok = new(big.Int).SetString(modpStr, 16)
	if !ok {
		panic("Failed to load the RFC3526 MODP Group")
	}
	gen = big.NewInt(g)
}
