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

package socks5

import "fmt"

const (
	authRFC1929Ver     = 0x01
	authRFC1929Success = 0x00
	authRFC1929Fail    = 0x01
)

func (req *Request) authRFC1929() (err error) {
	sendErrResp := func() {
		// Swallow write/flush errors, the auth failure is the relevant error.
		resp := []byte{authRFC1929Ver, authRFC1929Fail}
		req.rw.Write(resp[:])
		req.flushBuffers()
	}

	// The client sends a Username/Password request.
	//  uint8_t ver (0x01)
	//  uint8_t ulen (>= 1)
	//  uint8_t uname[ulen]
	//  uint8_t plen (>= 1)
	//  uint8_t passwd[plen]

	if err = req.readByteVerify("auth version", authRFC1929Ver); err != nil {
		sendErrResp()
		return
	}

	// Read the username.
	var ulen byte
	if ulen, err = req.readByte(); err != nil {
		sendErrResp()
		return
	} else if ulen < 1 {
		sendErrResp()
		return fmt.Errorf("username with 0 length")
	}
	var uname []byte
	if uname, err = req.readBytes(int(ulen)); err != nil {
		sendErrResp()
		return
	}

	// Read the password.
	var plen byte
	if plen, err = req.readByte(); err != nil {
		sendErrResp()
		return
	} else if plen < 1 {
		sendErrResp()
		return fmt.Errorf("password with 0 length")
	}
	var passwd []byte
	if passwd, err = req.readBytes(int(plen)); err != nil {
		sendErrResp()
		return
	}

	// Pluggable transports use the username/password field to pass
	// per-connection arguments.  The fields contain ASCII strings that
	// are combined and then parsed into key/value pairs.
	argStr := string(uname)
	if !(plen == 1 && passwd[0] == 0x00) {
		// tor will set the password to 'NUL', if the field doesn't contain any
		// actual argument data.
		argStr += string(passwd)
	}
	if req.Args, err = parseClientParameters(argStr); err != nil {
		sendErrResp()
		return
	}

	resp := []byte{authRFC1929Ver, authRFC1929Success}
	_, err = req.rw.Write(resp[:])
	return
}
