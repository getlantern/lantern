package pt

import (
	"bytes"
	"errors"
	"io"
	"net"
	"testing"
	"time"
)

func TestReadSocks4aConnect(t *testing.T) {
	badTests := [...][]byte{
		[]byte(""),
		// missing userid
		[]byte("\x04\x01\x12\x34\x01\x02\x03\x04"),
		// missing \x00 after userid
		[]byte("\x04\x01\x12\x34\x01\x02\x03\x04key=value"),
		// missing hostname
		[]byte("\x04\x01\x12\x34\x00\x00\x00\x01key=value\x00"),
		// missing \x00 after hostname
		[]byte("\x04\x01\x12\x34\x00\x00\x00\x01key=value\x00hostname"),
		// bad name–value mapping
		[]byte("\x04\x01\x12\x34\x00\x00\x00\x01userid\x00hostname\x00"),
		// bad version number
		[]byte("\x03\x01\x12\x34\x01\x02\x03\x04\x00"),
		// BIND request
		[]byte("\x04\x02\x12\x34\x01\x02\x03\x04\x00"),
		// SOCKS5
		[]byte("\x05\x01\x00"),
	}
	ipTests := [...]struct {
		input  []byte
		addr   net.TCPAddr
		userid string
	}{
		{
			[]byte("\x04\x01\x12\x34\x01\x02\x03\x04key=value\x00"),
			net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 0x1234},
			"key=value",
		},
		{
			[]byte("\x04\x01\x12\x34\x01\x02\x03\x04\x00"),
			net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 0x1234},
			"",
		},
	}
	hostnameTests := [...]struct {
		input  []byte
		target string
		userid string
	}{
		{
			[]byte("\x04\x01\x12\x34\x00\x00\x00\x01key=value\x00hostname\x00"),
			"hostname:4660",
			"key=value",
		},
		{
			[]byte("\x04\x01\x12\x34\x00\x00\x00\x01\x00hostname\x00"),
			"hostname:4660",
			"",
		},
		{
			[]byte("\x04\x01\x12\x34\x00\x00\x00\x01key=value\x00\x00"),
			":4660",
			"key=value",
		},
		{
			[]byte("\x04\x01\x12\x34\x00\x00\x00\x01\x00\x00"),
			":4660",
			"",
		},
	}

	for _, input := range badTests {
		var buf bytes.Buffer
		buf.Write(input)
		_, err := readSocks4aConnect(&buf)
		if err == nil {
			t.Errorf("%q unexpectedly succeeded", input)
		}
	}

	for _, test := range ipTests {
		var buf bytes.Buffer
		buf.Write(test.input)
		req, err := readSocks4aConnect(&buf)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", test.input, err)
		}
		addr, err := net.ResolveTCPAddr("tcp", req.Target)
		if err != nil {
			t.Errorf("%q → target %q: cannot resolve: %s", test.input,
				req.Target, err)
		}
		if !tcpAddrsEqual(addr, &test.addr) {
			t.Errorf("%q → address %s (expected %s)", test.input,
				req.Target, test.addr.String())
		}
		if req.Username != test.userid {
			t.Errorf("%q → username %q (expected %q)", test.input,
				req.Username, test.userid)
		}
		if req.Args == nil {
			t.Errorf("%q → unexpected nil Args from username %q", test.input, req.Username)
		}
	}

	for _, test := range hostnameTests {
		var buf bytes.Buffer
		buf.Write(test.input)
		req, err := readSocks4aConnect(&buf)
		if err != nil {
			t.Errorf("%q unexpectedly returned an error: %s", test.input, err)
		}
		if req.Target != test.target {
			t.Errorf("%q → target %q (expected %q)", test.input,
				req.Target, test.target)
		}
		if req.Username != test.userid {
			t.Errorf("%q → username %q (expected %q)", test.input,
				req.Username, test.userid)
		}
		if req.Args == nil {
			t.Errorf("%q → unexpected nil Args from username %q", test.input, req.Username)
		}
	}
}

func TestSendSocks4aResponse(t *testing.T) {
	tests := [...]struct {
		code     byte
		addr     net.TCPAddr
		expected []byte
	}{
		{
			socksRequestGranted,
			net.TCPAddr{IP: net.ParseIP("1.2.3.4"), Port: 0x1234},
			[]byte("\x00\x5a\x12\x34\x01\x02\x03\x04"),
		},
		{
			socksRequestRejected,
			net.TCPAddr{IP: net.ParseIP("1:2::3:4"), Port: 0x1234},
			[]byte("\x00\x5b\x12\x34\x00\x00\x00\x00"),
		},
	}

	for _, test := range tests {
		var buf bytes.Buffer
		err := sendSocks4aResponse(&buf, test.code, &test.addr)
		if err != nil {
			t.Errorf("0x%02x %s unexpectedly returned an error: %s", test.code, &test.addr, err)
		}
		p := make([]byte, 1024)
		n, err := buf.Read(p)
		if err != nil {
			t.Fatal(err)
		}
		output := p[:n]
		if !bytes.Equal(output, test.expected) {
			t.Errorf("0x%02x %s → %v (expected %v)",
				test.code, &test.addr, output, test.expected)
		}
	}
}

var fakeListenerDistinguishedError = errors.New("distinguished error")

// fakeListener is a fake dummy net.Listener that returns the given net.Conn and
// error the first time Accept is called. After the first call, it returns
// (nil, fakeListenerDistinguishedError).
type fakeListener struct {
	c   net.Conn
	err error
}

func (ln *fakeListener) Accept() (net.Conn, error) {
	c := ln.c
	err := ln.err
	ln.c = nil
	ln.err = fakeListenerDistinguishedError
	return c, err
}

func (ln *fakeListener) Close() error {
	return nil
}

func (ln *fakeListener) Addr() net.Addr {
	return &net.TCPAddr{IP: net.ParseIP("127.0.0.1"), Port: 0, Zone: ""}
}

// A trivial net.Error that lets you control whether it is considered Temporary.
type netError struct {
	errString string
	temporary bool
}

func (e *netError) Error() string {
	return e.errString
}

func (e *netError) Temporary() bool {
	return e.temporary
}

func (e *netError) Timeout() bool {
	return false
}

// The purpose of ignoreDeadlineConn is to wrap net.Pipe so that the deadline
// functions don't return an error ("net.Pipe does not support deadlines").
type ignoreDeadlineConn struct {
	net.Conn
}

func (c *ignoreDeadlineConn) SetDeadline(t time.Time) error {
	return nil
}

func (c *ignoreDeadlineConn) SetReadDeadline(t time.Time) error {
	return nil
}

func (c *ignoreDeadlineConn) SetWriteDeadline(t time.Time) error {
	return nil
}

func TestAcceptErrors(t *testing.T) {
	// Check that AcceptSocks accurately reflects net.Errors returned by the
	// underlying call to Accept. This is important for the handling of
	// Temporary and non-Temporary errors. The loop iterates over
	// non-net.Error, non-Temporary net.Error, and Temporary net.Error.
	for _, expectedErr := range []error{io.EOF, &netError{"non-temp", false}, &netError{"temp", true}} {
		ln := NewSocksListener(&fakeListener{nil, expectedErr})
		_, err := ln.AcceptSocks()
		if expectedNerr, ok := expectedErr.(net.Error); ok {
			nerr, ok := err.(net.Error)
			if !ok {
				t.Errorf("AcceptSocks returned non-net.Error %v", nerr)
			} else {
				if expectedNerr.Temporary() != expectedNerr.Temporary() {
					t.Errorf("AcceptSocks did not keep Temporary status of net.Error: %v", nerr)
				}
			}
		}
	}

	c1, c2 := net.Pipe()
	go func() {
		// Bogus request: SOCKS 5 then EOF.
		c2.Write([]byte("\x05\x01\x00"))
		c2.Close()
	}()
	ln := NewSocksListener(&fakeListener{c: &ignoreDeadlineConn{c1}, err: nil})
	_, err := ln.AcceptSocks()
	// The error in parsing the SOCKS request must be either silently
	// ignored, or else must be a Temporary net.Error. I.e., it must not be
	// the io.ErrUnexpectedEOF caused by the short request.
	if err == fakeListenerDistinguishedError {
		// Was silently ignored.
	} else if nerr, ok := err.(net.Error); ok {
		if !nerr.Temporary() {
			t.Errorf("AcceptSocks returned non-Temporary net.Error: %v", nerr)
		}
	} else {
		t.Errorf("AcceptSocks returned non-net.Error: %v", err)
	}
}
