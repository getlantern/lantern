// Copyright 2013 The Gorilla WebSocket Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package websocket

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"net"
	"reflect"
	"testing"
	"testing/iotest"
	"time"
)

var _ net.Error = errWriteTimeout

type fakeNetConn struct {
	io.Reader
	io.Writer
}

func (c fakeNetConn) Close() error                       { return nil }
func (c fakeNetConn) LocalAddr() net.Addr                { return nil }
func (c fakeNetConn) RemoteAddr() net.Addr               { return nil }
func (c fakeNetConn) SetDeadline(t time.Time) error      { return nil }
func (c fakeNetConn) SetReadDeadline(t time.Time) error  { return nil }
func (c fakeNetConn) SetWriteDeadline(t time.Time) error { return nil }

func TestFraming(t *testing.T) {
	frameSizes := []int{0, 1, 2, 124, 125, 126, 127, 128, 129, 65534, 65535, 65536, 65537}
	var readChunkers = []struct {
		name string
		f    func(io.Reader) io.Reader
	}{
		{"half", iotest.HalfReader},
		{"one", iotest.OneByteReader},
		{"asis", func(r io.Reader) io.Reader { return r }},
	}

	writeBuf := make([]byte, 65537)
	for i := range writeBuf {
		writeBuf[i] = byte(i)
	}

	for _, isServer := range []bool{true, false} {
		for _, chunker := range readChunkers {

			var connBuf bytes.Buffer
			wc := newConn(fakeNetConn{Reader: nil, Writer: &connBuf}, isServer, 1024, 1024)
			rc := newConn(fakeNetConn{Reader: chunker.f(&connBuf), Writer: nil}, !isServer, 1024, 1024)

			for _, n := range frameSizes {
				for _, iocopy := range []bool{true, false} {
					name := fmt.Sprintf("s:%v, r:%s, n:%d c:%v", isServer, chunker.name, n, iocopy)

					w, err := wc.NextWriter(TextMessage)
					if err != nil {
						t.Errorf("%s: wc.NextWriter() returned %v", name, err)
						continue
					}
					var nn int
					if iocopy {
						var n64 int64
						n64, err = io.Copy(w, bytes.NewReader(writeBuf[:n]))
						nn = int(n64)
					} else {
						nn, err = w.Write(writeBuf[:n])
					}
					if err != nil || nn != n {
						t.Errorf("%s: w.Write(writeBuf[:n]) returned %d, %v", name, nn, err)
						continue
					}
					err = w.Close()
					if err != nil {
						t.Errorf("%s: w.Close() returned %v", name, err)
						continue
					}

					opCode, r, err := rc.NextReader()
					if err != nil || opCode != TextMessage {
						t.Errorf("%s: NextReader() returned %d, r, %v", name, opCode, err)
						continue
					}
					rbuf, err := ioutil.ReadAll(r)
					if err != nil {
						t.Errorf("%s: ReadFull() returned rbuf, %v", name, err)
						continue
					}

					if len(rbuf) != n {
						t.Errorf("%s: len(rbuf) is %d, want %d", name, len(rbuf), n)
						continue
					}

					for i, b := range rbuf {
						if byte(i) != b {
							t.Errorf("%s: bad byte at offset %d", name, i)
							break
						}
					}
				}
			}
		}
	}
}

func TestControl(t *testing.T) {
	const message = "this is a ping/pong messsage"
	for _, isServer := range []bool{true, false} {
		for _, isWriteControl := range []bool{true, false} {
			name := fmt.Sprintf("s:%v, wc:%v", isServer, isWriteControl)
			var connBuf bytes.Buffer
			wc := newConn(fakeNetConn{Reader: nil, Writer: &connBuf}, isServer, 1024, 1024)
			rc := newConn(fakeNetConn{Reader: &connBuf, Writer: nil}, !isServer, 1024, 1024)
			if isWriteControl {
				wc.WriteControl(PongMessage, []byte(message), time.Now().Add(time.Second))
			} else {
				w, err := wc.NextWriter(PongMessage)
				if err != nil {
					t.Errorf("%s: wc.NextWriter() returned %v", name, err)
					continue
				}
				if _, err := w.Write([]byte(message)); err != nil {
					t.Errorf("%s: w.Write() returned %v", name, err)
					continue
				}
				if err := w.Close(); err != nil {
					t.Errorf("%s: w.Close() returned %v", name, err)
					continue
				}
				var actualMessage string
				rc.SetPongHandler(func(s string) error { actualMessage = s; return nil })
				rc.NextReader()
				if actualMessage != message {
					t.Errorf("%s: pong=%q, want %q", name, actualMessage, message)
					continue
				}
			}
		}
	}
}

func TestCloseBeforeFinalFrame(t *testing.T) {
	const bufSize = 512

	expectedErr := &CloseError{Code: CloseNormalClosure, Text: "hello"}

	var b1, b2 bytes.Buffer
	wc := newConn(fakeNetConn{Reader: nil, Writer: &b1}, false, 1024, bufSize)
	rc := newConn(fakeNetConn{Reader: &b1, Writer: &b2}, true, 1024, 1024)

	w, _ := wc.NextWriter(BinaryMessage)
	w.Write(make([]byte, bufSize+bufSize/2))
	wc.WriteControl(CloseMessage, FormatCloseMessage(expectedErr.Code, expectedErr.Text), time.Now().Add(10*time.Second))
	w.Close()

	op, r, err := rc.NextReader()
	if op != BinaryMessage || err != nil {
		t.Fatalf("NextReader() returned %d, %v", op, err)
	}
	_, err = io.Copy(ioutil.Discard, r)
	if !reflect.DeepEqual(err, expectedErr) {
		t.Fatalf("io.Copy() returned %v, want %v", err, expectedErr)
	}
	_, _, err = rc.NextReader()
	if !reflect.DeepEqual(err, expectedErr) {
		t.Fatalf("NextReader() returned %v, want %v", err, expectedErr)
	}
}

func TestEOFBeforeFinalFrame(t *testing.T) {
	const bufSize = 512

	var b1, b2 bytes.Buffer
	wc := newConn(fakeNetConn{Reader: nil, Writer: &b1}, false, 1024, bufSize)
	rc := newConn(fakeNetConn{Reader: &b1, Writer: &b2}, true, 1024, 1024)

	w, _ := wc.NextWriter(BinaryMessage)
	w.Write(make([]byte, bufSize+bufSize/2))

	op, r, err := rc.NextReader()
	if op != BinaryMessage || err != nil {
		t.Fatalf("NextReader() returned %d, %v", op, err)
	}
	_, err = io.Copy(ioutil.Discard, r)
	if err != errUnexpectedEOF {
		t.Fatalf("io.Copy() returned %v, want %v", err, errUnexpectedEOF)
	}
	_, _, err = rc.NextReader()
	if err != errUnexpectedEOF {
		t.Fatalf("NextReader() returned %v, want %v", err, errUnexpectedEOF)
	}
}

func TestReadLimit(t *testing.T) {

	const readLimit = 512
	message := make([]byte, readLimit+1)

	var b1, b2 bytes.Buffer
	wc := newConn(fakeNetConn{Reader: nil, Writer: &b1}, false, 1024, readLimit-2)
	rc := newConn(fakeNetConn{Reader: &b1, Writer: &b2}, true, 1024, 1024)
	rc.SetReadLimit(readLimit)

	// Send message at the limit with interleaved pong.
	w, _ := wc.NextWriter(BinaryMessage)
	w.Write(message[:readLimit-1])
	wc.WriteControl(PongMessage, []byte("this is a pong"), time.Now().Add(10*time.Second))
	w.Write(message[:1])
	w.Close()

	// Send message larger than the limit.
	wc.WriteMessage(BinaryMessage, message[:readLimit+1])

	op, _, err := rc.NextReader()
	if op != BinaryMessage || err != nil {
		t.Fatalf("1: NextReader() returned %d, %v", op, err)
	}
	op, r, err := rc.NextReader()
	if op != BinaryMessage || err != nil {
		t.Fatalf("2: NextReader() returned %d, %v", op, err)
	}
	_, err = io.Copy(ioutil.Discard, r)
	if err != ErrReadLimit {
		t.Fatalf("io.Copy() returned %v", err)
	}
}

func TestUnderlyingConn(t *testing.T) {
	var b1, b2 bytes.Buffer
	fc := fakeNetConn{Reader: &b1, Writer: &b2}
	c := newConn(fc, true, 1024, 1024)
	ul := c.UnderlyingConn()
	if ul != fc {
		t.Fatalf("Underlying conn is not what it should be.")
	}
}

func TestBufioReadBytes(t *testing.T) {

	// Test calling bufio.ReadBytes for value longer than read buffer size.

	m := make([]byte, 512)
	m[len(m)-1] = '\n'

	var b1, b2 bytes.Buffer
	wc := newConn(fakeNetConn{Reader: nil, Writer: &b1}, false, len(m)+64, len(m)+64)
	rc := newConn(fakeNetConn{Reader: &b1, Writer: &b2}, true, len(m)-64, len(m)-64)

	w, _ := wc.NextWriter(BinaryMessage)
	w.Write(m)
	w.Close()

	op, r, err := rc.NextReader()
	if op != BinaryMessage || err != nil {
		t.Fatalf("NextReader() returned %d, %v", op, err)
	}

	br := bufio.NewReader(r)
	p, err := br.ReadBytes('\n')
	if err != nil {
		t.Fatalf("ReadBytes() returned %v", err)
	}
	if len(p) != len(m) {
		t.Fatalf("read returnd %d bytes, want %d bytes", len(p), len(m))
	}
}

var closeErrorTests = []struct {
	err   error
	codes []int
	ok    bool
}{
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNormalClosure}, true},
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNoStatusReceived}, false},
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNoStatusReceived, CloseNormalClosure}, true},
	{errors.New("hello"), []int{CloseNormalClosure}, false},
}

func TestCloseError(t *testing.T) {
	for _, tt := range closeErrorTests {
		ok := IsCloseError(tt.err, tt.codes...)
		if ok != tt.ok {
			t.Errorf("IsCloseError(%#v, %#v) returned %v, want %v", tt.err, tt.codes, ok, tt.ok)
		}
	}
}

var unexpectedCloseErrorTests = []struct {
	err   error
	codes []int
	ok    bool
}{
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNormalClosure}, false},
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNoStatusReceived}, true},
	{&CloseError{Code: CloseNormalClosure}, []int{CloseNoStatusReceived, CloseNormalClosure}, false},
	{errors.New("hello"), []int{CloseNormalClosure}, false},
}

func TestUnexpectedCloseErrors(t *testing.T) {
	for _, tt := range unexpectedCloseErrorTests {
		ok := IsUnexpectedCloseError(tt.err, tt.codes...)
		if ok != tt.ok {
			t.Errorf("IsUnexpectedCloseError(%#v, %#v) returned %v, want %v", tt.err, tt.codes, ok, tt.ok)
		}
	}
}

type blockingWriter struct {
	c1, c2 chan struct{}
}

func (w blockingWriter) Write(p []byte) (int, error) {
	// Allow main to continue
	close(w.c1)
	// Wait for panic in main
	<-w.c2
	return len(p), nil
}

func TestConcurrentWritePanic(t *testing.T) {
	w := blockingWriter{make(chan struct{}), make(chan struct{})}
	c := newConn(fakeNetConn{Reader: nil, Writer: w}, false, 1024, 1024)
	go func() {
		c.WriteMessage(TextMessage, []byte{})
	}()

	// wait for goroutine to block in write.
	<-w.c1

	defer func() {
		close(w.c2)
		if v := recover(); v != nil {
			return
		}
	}()

	c.WriteMessage(TextMessage, []byte{})
	t.Fatal("should not get here")
}

type failingReader struct{}

func (r failingReader) Read(p []byte) (int, error) {
	return 0, io.EOF
}

func TestFailedConnectionReadPanic(t *testing.T) {
	c := newConn(fakeNetConn{Reader: failingReader{}, Writer: nil}, false, 1024, 1024)

	defer func() {
		if v := recover(); v != nil {
			return
		}
	}()

	for i := 0; i < 20000; i++ {
		c.ReadMessage()
	}
	t.Fatal("should not get here")
}
