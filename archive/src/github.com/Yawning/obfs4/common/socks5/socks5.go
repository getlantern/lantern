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

// Package socks5 implements a SOCKS 5 server and the required pluggable
// transport specific extensions.  For more information see RFC 1928 and RFC
// 1929.
//
// Notes:
//  * GSSAPI authentication, is NOT supported.
//  * Only the CONNECT command is supported.
//  * The authentication provided by the client is always accepted as it is
//    used as a channel to pass information rather than for authentication for
//    pluggable transports.
package socks5

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"net"
	"syscall"
	"time"

	"git.torproject.org/pluggable-transports/goptlib.git"
)

const (
	version = 0x05
	rsv     = 0x00

	cmdConnect = 0x01

	atypIPv4       = 0x01
	atypDomainName = 0x03
	atypIPv6       = 0x04

	authNoneRequired        = 0x00
	authUsernamePassword    = 0x02
	authNoAcceptableMethods = 0xff

	requestTimeout = 5 * time.Second
)

// ReplyCode is a SOCKS 5 reply code.
type ReplyCode byte

// The various SOCKS 5 reply codes from RFC 1928.
const (
	ReplySucceeded ReplyCode = iota
	ReplyGeneralFailure
	ReplyConnectionNotAllowed
	ReplyNetworkUnreachable
	ReplyHostUnreachable
	ReplyConnectionRefused
	ReplyTTLExpired
	ReplyCommandNotSupported
	ReplyAddressNotSupported
)

// Version returns a string suitable to be included in a call to Cmethod.
func Version() string {
	return "socks5"
}

// ErrorToReplyCode converts an error to the "best" reply code.
func ErrorToReplyCode(err error) ReplyCode {
	opErr, ok := err.(*net.OpError)
	if !ok {
		return ReplyGeneralFailure
	}

	errno, ok := opErr.Err.(syscall.Errno)
	if !ok {
		return ReplyGeneralFailure
	}
	switch errno {
	case syscall.EADDRNOTAVAIL:
		return ReplyAddressNotSupported
	case syscall.ETIMEDOUT:
		return ReplyTTLExpired
	case syscall.ENETUNREACH:
		return ReplyNetworkUnreachable
	case syscall.EHOSTUNREACH:
		return ReplyHostUnreachable
	case syscall.ECONNREFUSED, syscall.ECONNRESET:
		return ReplyConnectionRefused
	default:
		return ReplyGeneralFailure
	}
}

// Request describes a SOCKS 5 request.
type Request struct {
	Target string
	Args   pt.Args
	rw     *bufio.ReadWriter
}

// Handshake attempts to handle a incoming client handshake over the provided
// connection and receive the SOCKS5 request.  The routine handles sending
// appropriate errors if applicable, but will not close the connection.
func Handshake(conn net.Conn) (*Request, error) {
	// Arm the handshake timeout.
	var err error
	if err = conn.SetDeadline(time.Now().Add(requestTimeout)); err != nil {
		return nil, err
	}
	defer func() {
		// Disarm the handshake timeout, only propagate the error if
		// the handshake was successful.
		nerr := conn.SetDeadline(time.Time{})
		if err == nil {
			err = nerr
		}
	}()

	req := new(Request)
	req.rw = bufio.NewReadWriter(bufio.NewReader(conn), bufio.NewWriter(conn))

	// Negotiate the protocol version and authentication method.
	var method byte
	if method, err = req.negotiateAuth(); err != nil {
		return nil, err
	}

	// Authenticate if neccecary.
	if err = req.authenticate(method); err != nil {
		return nil, err
	}

	// Read the client command.
	if err = req.readCommand(); err != nil {
		return nil, err
	}

	return req, err
}

// Reply sends a SOCKS5 reply to the corresponding request.  The BND.ADDR and
// BND.PORT fields are always set to an address/port corresponding to
// "0.0.0.0:0".
func (req *Request) Reply(code ReplyCode) error {
	// The server sends a reply message.
	//  uint8_t ver (0x05)
	//  uint8_t rep
	//  uint8_t rsv (0x00)
	//  uint8_t atyp
	//  uint8_t bnd_addr[]
	//  uint16_t bnd_port

	var resp [4 + 4 + 2]byte
	resp[0] = version
	resp[1] = byte(code)
	resp[2] = rsv
	resp[3] = atypIPv4

	if _, err := req.rw.Write(resp[:]); err != nil {
		return err
	}

	return req.flushBuffers()
}

func (req *Request) negotiateAuth() (byte, error) {
	// The client sends a version identifier/selection message.
	//	uint8_t ver (0x05)
	//  uint8_t nmethods (>= 1).
	//  uint8_t methods[nmethods]

	var err error
	if err = req.readByteVerify("version", version); err != nil {
		return 0, err
	}

	// Read the number of methods, and the methods.
	var nmethods byte
	method := byte(authNoAcceptableMethods)
	if nmethods, err = req.readByte(); err != nil {
		return method, err
	}
	var methods []byte
	if methods, err = req.readBytes(int(nmethods)); err != nil {
		return 0, err
	}

	// Pick the best authentication method, prioritizing authenticating
	// over not if both options are present.
	if bytes.IndexByte(methods, authUsernamePassword) != -1 {
		method = authUsernamePassword
	} else if bytes.IndexByte(methods, authNoneRequired) != -1 {
		method = authNoneRequired
	}

	// The server sends a method selection message.
	//  uint8_t ver (0x05)
	//  uint8_t method
	msg := []byte{version, method}
	if _, err = req.rw.Write(msg); err != nil {
		return 0, err
	}

	return method, req.flushBuffers()
}

func (req *Request) authenticate(method byte) error {
	switch method {
	case authNoneRequired:
		// No authentication required.
	case authUsernamePassword:
		if err := req.authRFC1929(); err != nil {
			return err
		}
	case authNoAcceptableMethods:
		return fmt.Errorf("no acceptable authentication methods")
	default:
		// This should never happen as only supported auth methods should be
		// negotiated.
		return fmt.Errorf("negotiated unsupported method 0x%02x", method)
	}

	return req.flushBuffers()
}

func (req *Request) readCommand() error {
	// The client sends the request details.
	//  uint8_t ver (0x05)
	//  uint8_t cmd
	//  uint8_t rsv (0x00)
	//  uint8_t atyp
	//  uint8_t dst_addr[]
	//  uint16_t dst_port

	var err error
	if err = req.readByteVerify("version", version); err != nil {
		req.Reply(ReplyGeneralFailure)
		return err
	}
	if err = req.readByteVerify("command", cmdConnect); err != nil {
		req.Reply(ReplyCommandNotSupported)
		return err
	}
	if err = req.readByteVerify("reserved", rsv); err != nil {
		req.Reply(ReplyGeneralFailure)
		return err
	}

	// Read the destination address/port.
	var atyp byte
	var host string
	if atyp, err = req.readByte(); err != nil {
		req.Reply(ReplyGeneralFailure)
		return err
	}
	switch atyp {
	case atypIPv4:
		var addr []byte
		if addr, err = req.readBytes(net.IPv4len); err != nil {
			req.Reply(ReplyGeneralFailure)
			return err
		}
		host = net.IPv4(addr[0], addr[1], addr[2], addr[3]).String()
	case atypDomainName:
		var alen byte
		if alen, err = req.readByte(); err != nil {
			req.Reply(ReplyGeneralFailure)
			return err
		}
		if alen == 0 {
			req.Reply(ReplyGeneralFailure)
			return fmt.Errorf("domain name with 0 length")
		}
		var addr []byte
		if addr, err = req.readBytes(int(alen)); err != nil {
			req.Reply(ReplyGeneralFailure)
			return err
		}
		host = string(addr)
	case atypIPv6:
		var rawAddr []byte
		if rawAddr, err = req.readBytes(net.IPv6len); err != nil {
			req.Reply(ReplyGeneralFailure)
			return err
		}
		addr := make(net.IP, net.IPv6len)
		copy(addr[:], rawAddr[:])
		host = fmt.Sprintf("[%s]", addr.String())
	default:
		req.Reply(ReplyAddressNotSupported)
		return fmt.Errorf("unsupported address type 0x%02x", atyp)
	}
	var rawPort []byte
	if rawPort, err = req.readBytes(2); err != nil {
		req.Reply(ReplyGeneralFailure)
		return err
	}
	port := int(rawPort[0])<<8 | int(rawPort[1])
	req.Target = fmt.Sprintf("%s:%d", host, port)

	return req.flushBuffers()
}

func (req *Request) flushBuffers() error {
	if err := req.rw.Flush(); err != nil {
		return err
	}
	if req.rw.Reader.Buffered() > 0 {
		return fmt.Errorf("read buffer has %d bytes of trailing data", req.rw.Reader.Buffered())
	}
	return nil
}

func (req *Request) readByte() (byte, error) {
	return req.rw.ReadByte()
}

func (req *Request) readByteVerify(descr string, expected byte) error {
	val, err := req.rw.ReadByte()
	if err != nil {
		return err
	}
	if val != expected {
		return fmt.Errorf("message field '%s' was 0x%02x (expected 0x%02x)", descr, val, expected)
	}
	return nil
}

func (req *Request) readBytes(n int) ([]byte, error) {
	b := make([]byte, n)
	if _, err := io.ReadFull(req.rw, b); err != nil {
		return nil, err
	}
	return b, nil
}
