/*
 * Copyright (c) 2015, Yawning Angel <yawning at torproject dot org>
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

package scramblesuit

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"hash"
	"strconv"
	"time"

	"git.torproject.org/pluggable-transports/obfs4.git/common/csrand"
	"git.torproject.org/pluggable-transports/obfs4.git/common/uniformdh"
)

const (
	minHandshakeLength = uniformdh.Size + macLength*2
	maxHandshakeLength = 1532
	dhMinPadLength     = 0
	dhMaxPadLength     = 1308
	macLength          = 128 / 8 // HMAC-SHA256-128()

	kdfSecretLength = keyLength * 2
)

var (
	errMarkNotFoundYet = errors.New("mark not found yet")

	// ErrInvalidHandshake is the error returned when the handshake fails.
	ErrInvalidHandshake = errors.New("invalid handshake")
)

type ssDHClientHandshake struct {
	mac       hash.Hash
	keypair   *uniformdh.PrivateKey
	epochHour []byte
	padLen    int

	serverPublicKey *uniformdh.PublicKey
	serverMark      []byte
}

func (hs *ssDHClientHandshake) generateHandshake() ([]byte, error) {
	var buf bytes.Buffer
	hs.mac.Reset()

	// The client handshake is X | P_C | M_C | MAC(X | P_C | M_C | E)
	x, err := hs.keypair.PublicKey.Bytes()
	if err != nil {
		return nil, err
	}
	hs.mac.Write(x)
	mC := hs.mac.Sum(nil)[:macLength]
	pC, err := makePad(hs.padLen)
	if err != nil {
		return nil, err
	}

	// Write X, P_C, M_C.
	buf.Write(x)
	buf.Write(pC)
	buf.Write(mC)

	// Calculate and write the MAC.
	hs.epochHour = []byte(strconv.FormatInt(getEpochHour(), 10))
	hs.mac.Write(pC)
	hs.mac.Write(mC)
	hs.mac.Write(hs.epochHour)
	buf.Write(hs.mac.Sum(nil)[:macLength])

	return buf.Bytes(), nil
}

func (hs *ssDHClientHandshake) parseServerHandshake(resp []byte) (int, []byte, error) {
	if len(resp) < minHandshakeLength {
		return 0, nil, errMarkNotFoundYet
	}

	// The server response is Y | P_S | M_S | MAC(Y | P_S | M_S | E).
	if hs.serverPublicKey == nil {
		y := resp[:uniformdh.Size]

		// Pull out the public key, and derive the server mark.
		hs.serverPublicKey = &uniformdh.PublicKey{}
		if err := hs.serverPublicKey.SetBytes(y); err != nil {
			return 0, nil, err
		}
		hs.mac.Reset()
		hs.mac.Write(y)
		hs.serverMark = hs.mac.Sum(nil)[:macLength]
	}

	// Find the mark+MAC, if it exits.
	endPos := len(resp)
	if endPos > maxHandshakeLength-macLength {
		endPos = maxHandshakeLength - macLength
	}
	pos := bytes.Index(resp[uniformdh.Size:endPos], hs.serverMark)
	if pos == -1 {
		if len(resp) >= maxHandshakeLength {
			// Couldn't find the mark in a maximum length response.
			return 0, nil, ErrInvalidHandshake
		}
		return 0, nil, errMarkNotFoundYet
	} else if len(resp) < pos+2*macLength {
		// Didn't receive the full M_S.
		return 0, nil, errMarkNotFoundYet
	}
	pos += uniformdh.Size

	// Validate the MAC.
	hs.mac.Write(resp[uniformdh.Size : pos+macLength])
	hs.mac.Write(hs.epochHour)
	macCmp := hs.mac.Sum(nil)[:macLength]
	macRx := resp[pos+macLength : pos+2*macLength]
	if !hmac.Equal(macCmp, macRx) {
		return 0, nil, ErrInvalidHandshake
	}

	// Derive the shared secret.
	ss, err := uniformdh.Handshake(hs.keypair, hs.serverPublicKey)
	if err != nil {
		return 0, nil, err
	}
	seed := sha256.Sum256(ss)
	return pos + 2*macLength, seed[:], nil
}

func newDHClientHandshake(kB *ssSharedSecret, sessionKey *uniformdh.PrivateKey) *ssDHClientHandshake {
	hs := &ssDHClientHandshake{keypair: sessionKey}
	hs.mac = hmac.New(sha256.New, kB[:])
	hs.padLen = csrand.IntRange(dhMinPadLength, dhMaxPadLength)
	return hs
}

func getEpochHour() int64 {
	return time.Now().Unix() / 3600
}

func makePad(padLen int) ([]byte, error) {
	pad := make([]byte, padLen)
	if err := csrand.Bytes(pad); err != nil {
		return nil, err
	}
	return pad, nil
}
