// Copyright 2015 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package apptest provides utilities for testing an app.
//
// It is extremely incomplete, hence it being internal.
// For starters, it should support iOS.
package apptest

import (
	"bufio"
	"bytes"
	"fmt"
	"net"
)

// Port is the TCP port used to communicate with the test app.
//
// TODO(crawshaw): find a way to make this configurable. adb am extras?
const Port = "12533"

// Comm is a simple text-based communication protocol.
//
// Assumes all sides are friendly and cooperative and that the
// communication is over at the first sign of trouble.
type Comm struct {
	Conn   net.Conn
	Fatalf func(format string, args ...interface{})
	Printf func(format string, args ...interface{})

	scanner *bufio.Scanner
}

func (c *Comm) Send(cmd string, args ...interface{}) {
	buf := new(bytes.Buffer)
	buf.WriteString(cmd)
	for _, arg := range args {
		buf.WriteRune(' ')
		fmt.Fprintf(buf, "%v", arg)
	}
	buf.WriteRune('\n')
	b := buf.Bytes()
	c.Printf("comm.send: %s\n", b)
	if _, err := c.Conn.Write(b); err != nil {
		c.Fatalf("failed to send %s: %v", b, err)
	}
}

func (c *Comm) Recv(cmd string, a ...interface{}) {
	if c.scanner == nil {
		c.scanner = bufio.NewScanner(c.Conn)
	}
	if !c.scanner.Scan() {
		c.Fatalf("failed to recv %q: %v", cmd, c.scanner.Err())
	}
	text := c.scanner.Text()
	c.Printf("comm.recv: %s\n", text)
	var recvCmd string
	args := append([]interface{}{&recvCmd}, a...)
	if _, err := fmt.Sscan(text, args...); err != nil {
		c.Fatalf("cannot scan recv command %s: %q: %v", cmd, text, err)
	}
	if cmd != recvCmd {
		c.Fatalf("expecting recv %q, got %v", cmd, text)
	}
}
