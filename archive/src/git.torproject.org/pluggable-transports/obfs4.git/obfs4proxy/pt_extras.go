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

package main

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"

	"git.torproject.org/pluggable-transports/goptlib.git"
)

// This file contains things that probably should be in goptlib but are not
// yet or are not finalized.

func ptEnvError(msg string) error {
	line := []byte(fmt.Sprintf("ENV-ERROR %s\n", msg))
	pt.Stdout.Write(line)
	return errors.New(msg)
}

func ptProxyError(msg string) error {
	line := []byte(fmt.Sprintf("PROXY-ERROR %s\n", msg))
	pt.Stdout.Write(line)
	return errors.New(msg)
}

func ptProxyDone() {
	line := []byte("PROXY DONE\n")
	pt.Stdout.Write(line)
}

func ptIsClient() (bool, error) {
	clientEnv := os.Getenv("TOR_PT_CLIENT_TRANSPORTS")
	serverEnv := os.Getenv("TOR_PT_SERVER_TRANSPORTS")
	if clientEnv != "" && serverEnv != "" {
		return false, ptEnvError("TOR_PT_[CLIENT,SERVER]_TRANSPORTS both set")
	} else if clientEnv != "" {
		return true, nil
	} else if serverEnv != "" {
		return false, nil
	}
	return false, errors.New("not launched as a managed transport")
}

func ptGetProxy() (*url.URL, error) {
	specString := os.Getenv("TOR_PT_PROXY")
	if specString == "" {
		return nil, nil
	}
	spec, err := url.Parse(specString)
	if err != nil {
		return nil, ptProxyError(fmt.Sprintf("failed to parse proxy config: %s", err))
	}

	// Validate the TOR_PT_PROXY uri.
	if !spec.IsAbs() {
		return nil, ptProxyError("proxy URI is relative, must be absolute")
	}
	if spec.Path != "" {
		return nil, ptProxyError("proxy URI has a path defined")
	}
	if spec.RawQuery != "" {
		return nil, ptProxyError("proxy URI has a query defined")
	}
	if spec.Fragment != "" {
		return nil, ptProxyError("proxy URI has a fragment defined")
	}

	switch spec.Scheme {
	case "http":
		// The most forgiving of proxies.

	case "socks4a":
		if spec.User != nil {
			_, isSet := spec.User.Password()
			if isSet {
				return nil, ptProxyError("proxy URI specified SOCKS4a and a password")
			}
		}

	case "socks5":
		if spec.User != nil {
			// UNAME/PASSWD both must be between 1 and 255 bytes long. (RFC1929)
			user := spec.User.Username()
			passwd, isSet := spec.User.Password()
			if len(user) < 1 || len(user) > 255 {
				return nil, ptProxyError("proxy URI specified a invalid SOCKS5 username")
			}
			if !isSet || len(passwd) < 1 || len(passwd) > 255 {
				return nil, ptProxyError("proxy URI specified a invalid SOCKS5 password")
			}
		}

	default:
		return nil, ptProxyError(fmt.Sprintf("proxy URI has invalid scheme: %s", spec.Scheme))
	}

	_, err = resolveAddrStr(spec.Host)
	if err != nil {
		return nil, ptProxyError(fmt.Sprintf("proxy URI has invalid host: %s", err))
	}

	return spec, nil
}

// Sigh, pt.resolveAddr() isn't exported.  Include our own getto version that
// doesn't work around #7011, because we don't work with pre-0.2.5.x tor, and
// all we care about is validation anyway.
func resolveAddrStr(addrStr string) (*net.TCPAddr, error) {
	ipStr, portStr, err := net.SplitHostPort(addrStr)
	if err != nil {
		return nil, err
	}

	if ipStr == "" {
		return nil, net.InvalidAddrError(fmt.Sprintf("address string %q lacks a host part", addrStr))
	}
	if portStr == "" {
		return nil, net.InvalidAddrError(fmt.Sprintf("address string %q lacks a port part", addrStr))
	}
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return nil, net.InvalidAddrError(fmt.Sprintf("not an IP string: %q", ipStr))
	}
	port, err := strconv.ParseUint(portStr, 10, 16)
	if err != nil {
		return nil, net.InvalidAddrError(fmt.Sprintf("not a Port string: %q", portStr))
	}

	return &net.TCPAddr{IP: ip, Port: int(port), Zone: ""}, nil
}

// Feature #15435 adds a new env var for determining if Tor keeps stdin
// open for use in termination detection.
func ptShouldExitOnStdinClose() bool {
	return os.Getenv("TOR_PT_EXIT_ON_STDIN_CLOSE") == "1"
}
