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
	"crypto/hmac"
	"hash"
)

func hkdfExpand(hashFn func() hash.Hash, prk []byte, info []byte, l int) []byte {
	// Why, yes.  golang.org/x/crypto/hkdf exists, and is a fine
	// implementation of HKDF.  However it does both the extract
	// and expand, while ScrambleSuit only does extract, with no
	// way to separate the two steps.

	h := hmac.New(hashFn, prk)
	digestSz := h.Size()
	if l > 255*digestSz {
		panic("hkdf: requested OKM length > 255*HashLen")
	}

	var t []byte
	okm := make([]byte, 0, l)
	toAppend := l
	ctr := byte(1)
	for toAppend > 0 {
		h.Reset()
		h.Write(t)
		h.Write(info)
		h.Write([]byte{ctr})
		t = h.Sum(nil)
		ctr++

		aLen := digestSz
		if toAppend < digestSz {
			aLen = toAppend
		}
		okm = append(okm, t[:aLen]...)
		toAppend -= aLen
	}
	return okm
}
