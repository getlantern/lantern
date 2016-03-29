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

import (
	"fmt"
	"git.torproject.org/pluggable-transports/goptlib.git"
)

// parseClientParameters takes a client parameter string formatted according to
// "Passing PT-specific parameters to a client PT" in the pluggable transport
// specification, and returns it as a goptlib Args structure.
//
// This is functionally identical to the equivalently named goptlib routine.
func parseClientParameters(argStr string) (args pt.Args, err error) {
	args = make(pt.Args)
	if len(argStr) == 0 {
		return
	}

	var key string
	var acc []byte
	prevIsEscape := false
	for idx, ch := range []byte(argStr) {
		switch ch {
		case '\\':
			prevIsEscape = !prevIsEscape
			if prevIsEscape {
				continue
			}
		case '=':
			if !prevIsEscape {
				if key != "" {
					break
				}
				if len(acc) == 0 {
					return nil, fmt.Errorf("unexpected '=' at %d", idx)
				}
				key = string(acc)
				acc = nil
				continue
			}
		case ';':
			if !prevIsEscape {
				if key == "" || idx == len(argStr)-1 {
					return nil, fmt.Errorf("unexpected ';' at %d", idx)
				}
				args.Add(key, string(acc))
				key = ""
				acc = nil
				continue
			}
		default:
			if prevIsEscape {
				return nil, fmt.Errorf("unexpected '\\' at %d", idx-1)
			}
		}
		prevIsEscape = false
		acc = append(acc, ch)
	}
	if prevIsEscape {
		return nil, fmt.Errorf("underminated escape character")
	}
	// Handle the final k,v pair if any.
	if key == "" {
		return nil, fmt.Errorf("final key with no value")
	}
	args.Add(key, string(acc))

	return args, nil
}
