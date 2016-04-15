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
	"bufio"
	"fmt"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"

	"golang.org/x/net/proxy"
)

// httpProxy is a HTTP connect proxy.
type httpProxy struct {
	hostPort string
	haveAuth bool
	username string
	password string
	forward  proxy.Dialer
}

func newHTTP(uri *url.URL, forward proxy.Dialer) (proxy.Dialer, error) {
	s := new(httpProxy)
	s.hostPort = uri.Host
	s.forward = forward
	if uri.User != nil {
		s.haveAuth = true
		s.username = uri.User.Username()
		s.password, _ = uri.User.Password()
	}

	return s, nil
}

func (s *httpProxy) Dial(network, addr string) (net.Conn, error) {
	// Dial and create the http client connection.
	c, err := s.forward.Dial("tcp", s.hostPort)
	if err != nil {
		return nil, err
	}
	conn := new(httpConn)
	conn.httpConn = httputil.NewClientConn(c, nil)
	conn.remoteAddr, err = net.ResolveTCPAddr(network, addr)
	if err != nil {
		conn.httpConn.Close()
		return nil, err
	}

	// HACK HACK HACK HACK.  http.ReadRequest also does this.
	reqURL, err := url.Parse("http://" + addr)
	if err != nil {
		conn.httpConn.Close()
		return nil, err
	}
	reqURL.Scheme = ""

	req, err := http.NewRequest("CONNECT", reqURL.String(), nil)
	if err != nil {
		conn.httpConn.Close()
		return nil, err
	}
	req.Close = false
	if s.haveAuth {
		req.SetBasicAuth(s.username, s.password)
	}
	req.Header.Set("User-Agent", "")

	resp, err := conn.httpConn.Do(req)
	if err != nil && err != httputil.ErrPersistEOF {
		conn.httpConn.Close()
		return nil, err
	}
	if resp.StatusCode != 200 {
		conn.httpConn.Close()
		return nil, fmt.Errorf("proxy error: %s", resp.Status)
	}

	conn.hijackedConn, conn.staleReader = conn.httpConn.Hijack()
	return conn, nil
}

type httpConn struct {
	remoteAddr   *net.TCPAddr
	httpConn     *httputil.ClientConn
	hijackedConn net.Conn
	staleReader  *bufio.Reader
}

func (c *httpConn) Read(b []byte) (int, error) {
	if c.staleReader != nil {
		if c.staleReader.Buffered() > 0 {
			return c.staleReader.Read(b)
		}
		c.staleReader = nil
	}
	return c.hijackedConn.Read(b)
}

func (c *httpConn) Write(b []byte) (int, error) {
	return c.hijackedConn.Write(b)
}

func (c *httpConn) Close() error {
	return c.hijackedConn.Close()
}

func (c *httpConn) LocalAddr() net.Addr {
	return c.hijackedConn.LocalAddr()
}

func (c *httpConn) RemoteAddr() net.Addr {
	return c.remoteAddr
}

func (c *httpConn) SetDeadline(t time.Time) error {
	return c.hijackedConn.SetDeadline(t)
}

func (c *httpConn) SetReadDeadline(t time.Time) error {
	return c.hijackedConn.SetReadDeadline(t)
}

func (c *httpConn) SetWriteDeadline(t time.Time) error {
	return c.hijackedConn.SetWriteDeadline(t)
}

func init() {
	proxy.RegisterDialerType("http", newHTTP)
}
