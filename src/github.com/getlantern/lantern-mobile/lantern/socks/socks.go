package socks

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"time"
)

const (
	socks4Version = 0x04
	socks5Version = 0x05

	socksAuthNoneRequired        = 0x00
	socksAuthUsernamePassword    = 0x02
	socksAuthNoAcceptableMethods = 0xff

	socksCmdConnect = 0x01
	socksReserved   = 0x00

	socksAtypeV4         = 0x01
	socksAtypeDomainName = 0x03
	socksAtypeV6         = 0x04

	socksAuthRFC1929Ver     = 0x01
	socksAuthRFC1929Success = 0x00
	socksAuthRFC1929Fail    = 0x01

	socksRepSucceeded = 0x00
	// "general SOCKS server failure"
	SocksRepGeneralFailure = 0x01
	// "connection not allowed by ruleset"
	SocksRepConnectionNotAllowed = 0x02
	// "Network unreachable"
	SocksRepNetworkUnreachable = 0x03
	// "Host unreachable"
	SocksRepHostUnreachable = 0x04
	// "Connection refused"
	SocksRepConnectionRefused = 0x05
	// "TTL expired"
	SocksRepTTLExpired = 0x06
	// "Command not supported"
	SocksRepCommandNotSupported = 0x07
	// "Address type not supported"
	SocksRepAddressNotSupported = 0x08

	socks4ResponseVersion = 0x00
	socks4RequestGranted  = 0x5a
	socks4RequestRejected = 0x5b
)

// Put a sanity timeout on how long we wait for a SOCKS request.
const socksRequestTimeout = 5 * time.Second

// SocksRequest describes a SOCKS request.
type SocksRequest struct {
	// The endpoint requested by the client as a "host:port" string.
	Target string
	// The userid string sent by the client.
	Username string
	// The password string sent by the client.
	Password string
	// The parsed contents of Username as a key–value mapping.
	Args Args
}

// SocksConn encapsulates a net.Conn and information associated with a SOCKS request.
type SocksConn struct {
	net.Conn
	Req          SocksRequest
	socksVersion byte
}

// Send a message to the proxy client that access to the given address is
// granted.
// For SOCKS5, Addr is ignored, and "0.0.0.0:0" is always sent back for
// BND.ADDR/BND.PORT in the SOCKS response.
// For SOCKS4a, if the IP field inside addr is not an IPv4 address, the IP
// portion of the response will be four zero bytes.
func (conn *SocksConn) Grant(addr *net.TCPAddr) error {
	if conn.socksVersion == socks4Version {
		return sendSocks4aResponseGranted(conn, addr)
	}
	return sendSocks5ResponseGranted(conn)
}

// Send a message to the proxy client that access was rejected or failed.  This
// sends back a "General Failure" error code.  RejectReason should be used if
// more specific error reporting is desired.
func (conn *SocksConn) Reject() error {
	if conn.socksVersion == socks4Version {
		return sendSocks4aResponseRejected(conn)
	}
	return sendSocks5ResponseRejected(conn, SocksRepGeneralFailure)
}

// Send a message to the proxy client that access was rejected, with the
// specific error code indicating the reason behind the rejection.
// For SOCKS4a, the reason is ignored.
func (conn *SocksConn) RejectReason(reason byte) error {
	if conn.socksVersion == socks4Version {
		return sendSocks4aResponseRejected(conn)
	}
	return sendSocks5ResponseRejected(conn, reason)
}

// SocksListener wraps a net.Listener in order to read a SOCKS request on Accept.
//
// 	func handleConn(conn *pt.SocksConn) error {
// 		defer conn.Close()
// 		remote, err := net.Dial("tcp", conn.Req.Target)
// 		if err != nil {
// 			conn.Reject()
// 			return err
// 		}
// 		defer remote.Close()
// 		err = conn.Grant(remote.RemoteAddr().(*net.TCPAddr))
// 		if err != nil {
// 			return err
// 		}
// 		// do something with conn and remote
// 		return nil
// 	}
// 	...
// 	ln, err := pt.ListenSocks("tcp", "127.0.0.1:0")
// 	if err != nil {
// 		panic(err.Error())
// 	}
// 	for {
// 		conn, err := ln.AcceptSocks()
// 		if err != nil {
// 			log.Printf("accept error: %s", err)
// 			if e, ok := err.(net.Error); !ok || !e.Temporary() {
// 				break
// 			}
// 			continue
// 		}
// 		go handleConn(conn)
// 	}
type SocksListener struct {
	net.Listener
}

// Open a net.Listener according to network and laddr, and return it as a
// SocksListener.
func ListenSocks(network, laddr string) (*SocksListener, error) {
	ln, err := net.Listen(network, laddr)
	if err != nil {
		return nil, err
	}
	return NewSocksListener(ln), nil
}

// Create a new SocksListener wrapping the given net.Listener.
func NewSocksListener(ln net.Listener) *SocksListener {
	return &SocksListener{ln}
}

// Accept is the same as AcceptSocks, except that it returns a generic net.Conn.
// It is present for the sake of satisfying the net.Listener interface.
func (ln *SocksListener) Accept() (net.Conn, error) {
	return ln.AcceptSocks()
}

// Call Accept on the wrapped net.Listener, do SOCKS negotiation, and return a
// SocksConn. After accepting, you must call either conn.Grant or conn.Reject
// (presumably after trying to connect to conn.Req.Target).
//
// Errors returned by AcceptSocks may be temporary (for example, EOF while
// reading the request, or a badly formatted userid string), or permanent (e.g.,
// the underlying socket is closed). You can determine whether an error is
// temporary and take appropriate action with a type conversion to net.Error.
// For example:
//
// 	for {
// 		conn, err := ln.AcceptSocks()
// 		if err != nil {
// 			if e, ok := err.(net.Error); ok && e.Temporary() {
// 				log.Printf("temporary accept error; trying again: %s", err)
// 				continue
// 			}
// 			log.Printf("permanent accept error; giving up: %s", err)
// 			break
// 		}
// 		go handleConn(conn)
// 	}
func (ln *SocksListener) AcceptSocks() (*SocksConn, error) {
	c, err := ln.Listener.Accept()
	if err != nil {
		return nil, err
	}
	conn := new(SocksConn)
	conn.Conn = c

	err = conn.SetDeadline(time.Now().Add(socksRequestTimeout))
	if err != nil {
		conn.Close()
		err = newTemporaryNetError("AcceptSocks: conn.SetDeadline() #1 failed: %s", err.Error())
		return nil, err
	}

	rw := bufio.NewReadWriter(bufio.NewReader(conn), bufio.NewWriter(conn))

	// Determine which SOCKS version the client is using and branch on it.
	if version, err := socksPeekByte(rw.Reader); err != nil {
		conn.Close()
		err = newTemporaryNetError("AcceptSocks: socksPeekByte() failed: %s", err.Error())
		return nil, err
	} else if version == socks4Version {
		conn.socksVersion = socks4Version
		conn.Req, err = readSocks4aConnect(rw.Reader)
		if err != nil {
			conn.Close()
			return nil, err
		}
	} else if version == socks5Version {
		conn.socksVersion = socks5Version
		conn.Req, err = socks5Handshake(rw)
		if err != nil {
			conn.Close()
			return nil, err
		}
	} else {
		conn.Close()
		err = newTemporaryNetError("AcceptSocks: Illegal SOCKS version: 0x%02x", version)
		return nil, err
	}

	err = conn.SetDeadline(time.Time{})
	if err != nil {
		conn.Close()
		err = newTemporaryNetError("AcceptSocks: conn.SetDeadline() #2 failed: %s", err.Error())
		return nil, err

	}
	return conn, nil
}

// Returns "socks5", suitable to be included in a call to Cmethod.
func (ln *SocksListener) Version() string {
	return "socks5"
}

// socks5handshake conducts the SOCKS5 handshake up to the point where the
// client command is read and the proxy must open the outgoing connection.
// Returns a SocksRequest.
func socks5Handshake(rw *bufio.ReadWriter) (req SocksRequest, err error) {
	// Negotiate the authentication method.
	var method byte
	if method, err = socks5NegotiateAuth(rw); err != nil {
		return
	}

	// Authenticate the client.
	if err = socks5Authenticate(rw, method, &req); err != nil {
		return
	}

	// Read the command.
	err = socks5ReadCommand(rw, &req)
	return
}

// socks5NegotiateAuth negotiates the authentication method and returns the
// selected method as a byte.  On negotiation failures an error is returned.
func socks5NegotiateAuth(rw *bufio.ReadWriter) (method byte, err error) {
	// Validate the version.
	if err = socksReadByteVerify(rw.Reader, "version", socks5Version); err != nil {
		err = newTemporaryNetError("socks5NegotiateAuth: %s", err.Error())
		return
	}

	// Read the number of methods.
	var nmethods byte
	if nmethods, err = socksReadByte(rw.Reader); err != nil {
		err = newTemporaryNetError("socks5NegotiateAuth: Failed to read nmethods byte: %s", err.Error())
		return
	}

	// Read the methods.
	var methods []byte
	if methods, err = socksReadBytes(rw.Reader, int(nmethods)); err != nil {
		err = newTemporaryNetError("socks5NegotiateAuth: Failed to read methods bytes: %s", err.Error())
		return
	}

	// Pick the most "suitable" method.
	method = socksAuthNoAcceptableMethods
	for _, m := range methods {
		switch m {
		case socksAuthNoneRequired:
			// Pick Username/Password over None if the client happens to
			// send both.
			if method == socksAuthNoAcceptableMethods {
				method = m
			}

		case socksAuthUsernamePassword:
			method = m
		}
	}

	// Send the negotiated method.
	var msg [2]byte
	msg[0] = socks5Version
	msg[1] = method
	if _, err = rw.Writer.Write(msg[:]); err != nil {
		err = newTemporaryNetError("socks5NegotiateAuth: Failed to write negotiated method: %s", err.Error())
		return
	}

	if err = socksFlushBuffers(rw); err != nil {
		err = newTemporaryNetError("socks5NegotiateAuth: Failed to flush buffers: %s", err.Error())
		return
	}
	return
}

// socks5Authenticate authenticates the client via the chosen authentication
// mechanism.
func socks5Authenticate(rw *bufio.ReadWriter, method byte, req *SocksRequest) (err error) {
	switch method {
	case socksAuthNoneRequired:
		// Straight into reading the connect.

	case socksAuthUsernamePassword:
		if err = socks5AuthRFC1929(rw, req); err != nil {
			return
		}

	case socksAuthNoAcceptableMethods:
		err = newTemporaryNetError("socks5Authenticate: SOCKS method select had no compatible methods")
		return

	default:
		err = newTemporaryNetError("socks5Authenticate: SOCKS method select picked a unsupported method 0x%02x", method)
		return
	}

	if err = socksFlushBuffers(rw); err != nil {
		err = newTemporaryNetError("socks5Authenticate: Failed to flush buffers: %s", err)
		return
	}
	return
}

// socks5AuthRFC1929 authenticates the client via RFC 1929 username/password
// auth.  As a design decision any valid username/password is accepted as this
// field is primarily used as an out-of-band argument passing mechanism for
// pluggable transports.
func socks5AuthRFC1929(rw *bufio.ReadWriter, req *SocksRequest) (err error) {
	sendErrResp := func() {
		// Swallow the write/flush error here, we are going to close the
		// connection and the original failure is more useful.
		resp := []byte{socksAuthRFC1929Ver, socksAuthRFC1929Fail}
		rw.Write(resp[:])
		socksFlushBuffers(rw)
	}

	// Validate the fixed parts of the command message.
	if err = socksReadByteVerify(rw.Reader, "auth version", socksAuthRFC1929Ver); err != nil {
		sendErrResp()
		err = newTemporaryNetError("socks5AuthRFC1929: %s", err)
		return
	}

	// Read the username.
	var ulen byte
	if ulen, err = socksReadByte(rw.Reader); err != nil {
		err = newTemporaryNetError("socks5AuthRFC1929: Failed to read username length: %s", err)
		return
	}
	if ulen < 1 {
		sendErrResp()
		err = newTemporaryNetError("socks5AuthRFC1929: username with 0 length")
		return
	}
	var uname []byte
	if uname, err = socksReadBytes(rw.Reader, int(ulen)); err != nil {
		err = newTemporaryNetError("socks5AuthRFC1929: Failed to read username: %s", err)
		return
	}
	req.Username = string(uname)

	// Read the password.
	var plen byte
	if plen, err = socksReadByte(rw.Reader); err != nil {
		err = newTemporaryNetError("socks5AuthRFC1929: Failed to read password length: %s", err)
		return
	}
	if plen < 1 {
		sendErrResp()
		err = newTemporaryNetError("socks5AuthRFC1929: password with 0 length")
		return
	}
	var passwd []byte
	if passwd, err = socksReadBytes(rw.Reader, int(plen)); err != nil {
		err = newTemporaryNetError("socks5AuthRFC1929: Failed to read password: %s", err)
		return
	}
	if !(plen == 1 && passwd[0] == 0x00) {
		// tor will set the password to 'NUL' if there are no arguments.
		req.Password = string(passwd)
	}

	// Mash the username/password together and parse it as a pluggable
	// transport argument string.
	if req.Args, err = parseClientParameters(req.Username + req.Password); err != nil {
		sendErrResp()
		err = newTemporaryNetError("socks5AuthRFC1929: failed to parse client parameters: %s", err)
		return
	}

	// Write success response
	resp := []byte{socksAuthRFC1929Ver, socksAuthRFC1929Success}
	if _, err = rw.Write(resp[:]); err != nil {
		err = newTemporaryNetError("socks5AuthRFC1929: failed to write success response: %s", err)
		return
	}
	return
}

// socks5ReadCommand reads a SOCKS5 client command and parses out the relevant
// fields into a SocksRequest.  Only CMD_CONNECT is supported.
func socks5ReadCommand(rw *bufio.ReadWriter, req *SocksRequest) (err error) {
	sendErrResp := func(reason byte) {
		// Swallow errors that occur when writing/flushing the response,
		// connection will be closed anyway.
		sendSocks5ResponseRejected(rw, reason)
		socksFlushBuffers(rw)
	}

	// Validate the fixed parts of the command message.
	if err = socksReadByteVerify(rw.Reader, "version", socks5Version); err != nil {
		sendErrResp(SocksRepGeneralFailure)
		err = newTemporaryNetError("socks5ReadCommand: %s", err)
		return
	}
	if err = socksReadByteVerify(rw.Reader, "command", socksCmdConnect); err != nil {
		sendErrResp(SocksRepCommandNotSupported)
		err = newTemporaryNetError("socks5ReadCommand: %s", err)
		return
	}
	if err = socksReadByteVerify(rw.Reader, "reserved", socksReserved); err != nil {
		sendErrResp(SocksRepGeneralFailure)
		err = newTemporaryNetError("socks5ReadCommand: %s", err)
		return
	}

	// Read the destination address/port.
	// XXX: This should probably eventually send socks 5 error messages instead
	// of rudely closing connections on invalid addresses.
	var atype byte
	if atype, err = socksReadByte(rw.Reader); err != nil {
		err = newTemporaryNetError("socks5ReadCommand: Failed to read address type: %s", err)
		return
	}
	var host string
	switch atype {
	case socksAtypeV4:
		var addr []byte
		if addr, err = socksReadBytes(rw.Reader, net.IPv4len); err != nil {
			err = newTemporaryNetError("socks5ReadCommand: Failed to read IPv4 address: %s", err)
			return
		}
		host = net.IPv4(addr[0], addr[1], addr[2], addr[3]).String()

	case socksAtypeDomainName:
		var alen byte
		if alen, err = socksReadByte(rw.Reader); err != nil {
			err = newTemporaryNetError("socks5ReadCommand: Failed to read domain name length: %s", err)
			return
		}
		if alen == 0 {
			err = newTemporaryNetError("socks5ReadCommand: SOCKS request had domain name with 0 length")
			return
		}
		var addr []byte
		if addr, err = socksReadBytes(rw.Reader, int(alen)); err != nil {
			err = newTemporaryNetError("socks5ReadCommand: Failed to read domain name: %s", err)
			return
		}
		host = string(addr)

	case socksAtypeV6:
		var rawAddr []byte
		if rawAddr, err = socksReadBytes(rw.Reader, net.IPv6len); err != nil {
			err = newTemporaryNetError("socks5ReadCommand: Failed to read IPv6 address: %s", err)
			return
		}
		addr := make(net.IP, net.IPv6len)
		copy(addr[:], rawAddr[:])
		host = fmt.Sprintf("[%s]", addr.String())

	default:
		sendErrResp(SocksRepAddressNotSupported)
		err = newTemporaryNetError("socks5ReadCommand: SOCKS request had unsupported address type 0x%02x", atype)
		return
	}
	var rawPort []byte
	if rawPort, err = socksReadBytes(rw.Reader, 2); err != nil {
		err = newTemporaryNetError("socks5ReadCommand: Failed to read port number: %s", err)
		return
	}
	port := int(rawPort[0])<<8 | int(rawPort[1])<<0

	if err = socksFlushBuffers(rw); err != nil {
		err = newTemporaryNetError("socks5ReadCommand: Failed to flush buffers: %s", err)
		return
	}

	req.Target = fmt.Sprintf("%s:%d", host, port)
	return
}

// Send a SOCKS5 response with the given code. BND.ADDR/BND.PORT is always the
// IPv4 address/port "0.0.0.0:0".
func sendSocks5Response(w io.Writer, code byte) error {
	resp := make([]byte, 4+4+2)
	resp[0] = socks5Version
	resp[1] = code
	resp[2] = socksReserved
	resp[3] = socksAtypeV4

	// BND.ADDR/BND.PORT should be the address and port that the outgoing
	// connection is bound to on the proxy, but Tor does not use this
	// information, so all zeroes are sent.

	if _, err := w.Write(resp[:]); err != nil {
		err = newTemporaryNetError("sendSocks5Response: Failed write response: %s", err)
		return err
	}

	return nil
}

// Send a SOCKS5 response code 0x00.
func sendSocks5ResponseGranted(w io.Writer) error {
	return sendSocks5Response(w, socksRepSucceeded)
}

// Send a SOCKS5 response with the provided failure reason.
func sendSocks5ResponseRejected(w io.Writer, reason byte) error {
	return sendSocks5Response(w, reason)
}

/*
 * Common helpers
 */

func socksFlushBuffers(rw *bufio.ReadWriter) error {
	if err := rw.Writer.Flush(); err != nil {
		return err
	}
	if err := socksFlushReadBuffer(rw.Reader); err != nil {
		return err
	}
	return nil
}

func socksFlushReadBuffer(r *bufio.Reader) error {
	if r.Buffered() > 0 {
		return fmt.Errorf("%d bytes left after SOCKS message", r.Buffered())
	}
	return nil
}

func socksReadByte(r *bufio.Reader) (byte, error) {
	return r.ReadByte()
}

func socksReadBytes(r *bufio.Reader, n int) ([]byte, error) {
	ret := make([]byte, n)
	if _, err := io.ReadFull(r, ret); err != nil {
		return nil, err
	}
	return ret, nil
}

func socksReadByteVerify(r *bufio.Reader, descr string, expected byte) error {
	val, err := socksReadByte(r)
	if err != nil {
		return err
	}
	if val != expected {
		return fmt.Errorf("SOCKS message field %s was 0x%02x, not 0x%02x", descr, val, expected)
	}
	return nil
}

func socksReadBytesUntil(r *bufio.Reader, end byte) ([]byte, error) {
	val, err := r.ReadBytes(end)
	if err != nil {
		return nil, err
	}
	return val, nil
}

func socksPeekByte(r *bufio.Reader) (b byte, err error) {
	var byteSlice []byte
	if byteSlice, err = r.Peek(1); err != nil {
		return
	}
	b = byteSlice[0]
	return
}

// temporaryNetError is used for our custom errors. All such errors are "temporary";
// that is, the listener doesn't need to be torn down when they occur. They also
// need to implement the net.Error interface.
type temporaryNetError struct {
	error
}

// Ensure temporaryNetError implements net.Error
var _ net.Error = temporaryNetError{}

func newTemporaryNetError(errMsg string, args ...interface{}) *temporaryNetError {
	return &temporaryNetError{
		error: fmt.Errorf(errMsg, args...),
	}
}

func (tne temporaryNetError) Timeout() bool {
	return false
}

func (tne temporaryNetError) Temporary() bool {
	return true
}

/*
 * SOCKS4a-specific code
 */

// Read a SOCKS4a connect request. Returns a SocksRequest.
func readSocks4aConnect(r *bufio.Reader) (req SocksRequest, err error) {
	// Validate the version.
	if err = socksReadByteVerify(r, "version", socks4Version); err != nil {
		err = newTemporaryNetError("readSocks4aConnect: %s", err.Error())
		return
	}

	var cmdConnect byte
	if cmdConnect, err = socksReadByte(r); err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to read connect command: %s", err.Error())
		return
	}
	if cmdConnect != socksCmdConnect {
		err = newTemporaryNetError("readSocks4aConnect: SOCKS header had command 0x%02x, not 0x%02x", cmdConnect, socksCmdConnect)
		return
	}

	var rawPort []byte
	if rawPort, err = socksReadBytes(r, 2); err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to read port: %s", err.Error())
		return
	}
	port := int(rawPort[0])<<8 | int(rawPort[1])<<0

	var rawHostIP []byte
	if rawHostIP, err = socksReadBytes(r, 4); err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to read IP address: %s", err.Error())
		return
	}
	// If there's a hostname, it comes after the username, so we'll wait a bit
	// before we process the IP info.

	var usernameBytes []byte
	usernameBytes, err = socksReadBytesUntil(r, '\x00')
	if err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to read username: %s", err.Error())
		return
	}
	req.Username = string(usernameBytes[:len(usernameBytes)-1])

	req.Args, err = parseClientParameters(req.Username)
	if err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to parse client parameters: %s", err.Error())
		return
	}

	var host string
	if rawHostIP[0] == 0 && rawHostIP[1] == 0 && rawHostIP[2] == 0 && rawHostIP[3] != 0 {
		// If the IP is of the form 0.0.0.x (with x nonzero), then a domain name is provided.
		var hostBytes []byte
		if hostBytes, err = socksReadBytesUntil(r, '\x00'); err != nil {
			err = newTemporaryNetError("readSocks4aConnect: Failed to read domain name: %s", err.Error())
			return
		}
		host = string(hostBytes[:len(hostBytes)-1])
	} else {
		host = net.IPv4(rawHostIP[0], rawHostIP[1], rawHostIP[2], rawHostIP[3]).String()
	}

	req.Target = fmt.Sprintf("%s:%d", host, port)

	if err = socksFlushReadBuffer(r); err != nil {
		err = newTemporaryNetError("readSocks4aConnect: Failed to flush buffers: %s", err.Error())
		return
	}

	return
}

// Send a SOCKS4a response with the given code and address. If the IP field
// inside addr is not an IPv4 address, the IP portion of the response will be
// four zero bytes.
func sendSocks4aResponse(w io.Writer, code byte, addr *net.TCPAddr) error {
	var resp [8]byte
	resp[0] = socks4ResponseVersion
	resp[1] = code
	resp[2] = byte((addr.Port >> 8) & 0xff)
	resp[3] = byte((addr.Port >> 0) & 0xff)
	ipv4 := addr.IP.To4()
	if ipv4 != nil {
		resp[4] = ipv4[0]
		resp[5] = ipv4[1]
		resp[6] = ipv4[2]
		resp[7] = ipv4[3]
	}

	if _, err := w.Write(resp[:]); err != nil {
		err = newTemporaryNetError("sendSocks4aResponse: Failed to write response: %s", err.Error())
		return err
	}

	return nil
}

// Send a SOCKS4a response code 0x5a.
func sendSocks4aResponseGranted(w io.Writer, addr *net.TCPAddr) error {
	return sendSocks4aResponse(w, socks4RequestGranted, addr)
}

// Send a SOCKS4a response code 0x5b (with an all-zero address).
func sendSocks4aResponseRejected(w io.Writer) error {
	emptyAddr := net.TCPAddr{IP: net.IPv4(0, 0, 0, 0), Port: 0}
	return sendSocks4aResponse(w, socks4RequestRejected, &emptyAddr)
}
