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

// Package obfs2 provides an implementation of the Tor Project's obfs2
// obfuscation protocol.  This protocol is considered trivially broken by most
// sophisticated adversaries.
package obfs2

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"time"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/common/csrand"
	"git.torproject.org/pluggable-transports/obfs4.git/transports/base"
)

const (
	transportName   = "obfs2"
	sharedSecretArg = "shared-secret"

	clientHandshakeTimeout = time.Duration(30) * time.Second
	serverHandshakeTimeout = time.Duration(30) * time.Second

	magicValue         = 0x2bf5ca7e
	initiatorPadString = "Initiator obfuscation padding"
	responderPadString = "Responder obfuscation padding"
	initiatorKdfString = "Initiator obfuscated data"
	responderKdfString = "Responder obfuscated data"
	maxPadding         = 8192
	keyLen             = 16
	seedLen            = 16
	hsLen              = 4 + 4
)

func validateArgs(args *pt.Args) error {
	if _, ok := args.Get(sharedSecretArg); ok {
		// "shared-secret" is something no bridges use in practice and is thus
		// unimplemented.
		return fmt.Errorf("unsupported argument '%s'", sharedSecretArg)
	}
	return nil
}

// Transport is the obfs2 implementation of the base.Transport interface.
type Transport struct{}

// Name returns the name of the obfs2 transport protocol.
func (t *Transport) Name() string {
	return transportName
}

// ClientFactory returns a new obfs2ClientFactory instance.
func (t *Transport) ClientFactory(stateDir string) (base.ClientFactory, error) {
	cf := &obfs2ClientFactory{transport: t}
	return cf, nil
}

// ServerFactory returns a new obfs2ServerFactory instance.
func (t *Transport) ServerFactory(stateDir string, args *pt.Args) (base.ServerFactory, error) {
	if err := validateArgs(args); err != nil {
		return nil, err
	}

	sf := &obfs2ServerFactory{t}
	return sf, nil
}

type obfs2ClientFactory struct {
	transport base.Transport
}

func (cf *obfs2ClientFactory) Transport() base.Transport {
	return cf.transport
}

func (cf *obfs2ClientFactory) ParseArgs(args *pt.Args) (interface{}, error) {
	return nil, validateArgs(args)
}

func (cf *obfs2ClientFactory) Dial(network, addr string, dialFn base.DialFunc, args interface{}) (net.Conn, error) {
	conn, err := dialFn(network, addr)
	if err != nil {
		return nil, err
	}
	dialConn := conn
	if conn, err = newObfs2ClientConn(conn); err != nil {
		dialConn.Close()
		return nil, err
	}
	return conn, nil
}

type obfs2ServerFactory struct {
	transport base.Transport
}

func (sf *obfs2ServerFactory) Transport() base.Transport {
	return sf.transport
}

func (sf *obfs2ServerFactory) Args() *pt.Args {
	return nil
}

func (sf *obfs2ServerFactory) WrapConn(conn net.Conn) (net.Conn, error) {
	return newObfs2ServerConn(conn)
}

type obfs2Conn struct {
	net.Conn

	isInitiator bool

	rx *cipher.StreamReader
	tx *cipher.StreamWriter
}

func (conn *obfs2Conn) Read(b []byte) (int, error) {
	return conn.rx.Read(b)
}

func (conn *obfs2Conn) Write(b []byte) (int, error) {
	return conn.tx.Write(b)
}

func newObfs2ClientConn(conn net.Conn) (c *obfs2Conn, err error) {
	// Initialize a client connection, and start the handshake timeout.
	c = &obfs2Conn{conn, true, nil, nil}
	deadline := time.Now().Add(clientHandshakeTimeout)
	if err = c.SetDeadline(deadline); err != nil {
		return nil, err
	}

	// Handshake.
	if err = c.handshake(); err != nil {
		return nil, err
	}

	// Disarm the handshake timer.
	if err = c.SetDeadline(time.Time{}); err != nil {
		return nil, err
	}

	return
}

func newObfs2ServerConn(conn net.Conn) (c *obfs2Conn, err error) {
	// Initialize a server connection, and start the handshake timeout.
	c = &obfs2Conn{conn, false, nil, nil}
	deadline := time.Now().Add(serverHandshakeTimeout)
	if err = c.SetDeadline(deadline); err != nil {
		return nil, err
	}

	// Handshake.
	if err = c.handshake(); err != nil {
		return nil, err
	}

	// Disarm the handshake timer.
	if err = c.SetDeadline(time.Time{}); err != nil {
		return nil, err
	}

	return
}

func (conn *obfs2Conn) handshake() error {
	// Each begins by generating a seed and a padding key as follows.
	// The initiator generates:
	//
	//  INIT_SEED = SR(SEED_LENGTH)
	//  INIT_PAD_KEY = MAC("Initiator obfuscation padding", INIT_SEED)[:KEYLEN]
	//
	// And the responder generates:
	//
	//  RESP_SEED = SR(SEED_LENGTH)
	//  RESP_PAD_KEY = MAC("Responder obfuscation padding", INIT_SEED)[:KEYLEN]
	//
	// Each then generates a random number PADLEN in range from 0 through
	// MAX_PADDING (inclusive).
	var seed [seedLen]byte
	if err := csrand.Bytes(seed[:]); err != nil {
		return err
	}
	var padMagic []byte
	if conn.isInitiator {
		padMagic = []byte(initiatorPadString)
	} else {
		padMagic = []byte(responderPadString)
	}
	padKey, padIV := hsKdf(padMagic, seed[:], conn.isInitiator)
	padLen := uint32(csrand.IntRange(0, maxPadding))

	hsBlob := make([]byte, hsLen+padLen)
	binary.BigEndian.PutUint32(hsBlob[0:4], magicValue)
	binary.BigEndian.PutUint32(hsBlob[4:8], padLen)
	if padLen > 0 {
		if err := csrand.Bytes(hsBlob[8:]); err != nil {
			return err
		}
	}

	// The initiator then sends:
	//
	//  INIT_SEED | E(INIT_PAD_KEY, UINT32(MAGIC_VALUE) | UINT32(PADLEN) | WR(PADLEN))
	//
	// and the responder sends:
	//
	//  RESP_SEED | E(RESP_PAD_KEY, UINT32(MAGIC_VALUE) | UINT32(PADLEN) | WR(PADLEN))
	txBlock, err := aes.NewCipher(padKey)
	if err != nil {
		return err
	}
	txStream := cipher.NewCTR(txBlock, padIV)
	conn.tx = &cipher.StreamWriter{S: txStream, W: conn.Conn}
	if _, err := conn.Conn.Write(seed[:]); err != nil {
		return err
	}
	if _, err := conn.Write(hsBlob); err != nil {
		return err
	}

	// Upon receiving the SEED from the other party, each party derives
	// the other party's padding key value as above, and decrypts the next
	// 8 bytes of the key establishment message.
	var peerSeed [seedLen]byte
	if _, err := io.ReadFull(conn.Conn, peerSeed[:]); err != nil {
		return err
	}
	var peerPadMagic []byte
	if conn.isInitiator {
		peerPadMagic = []byte(responderPadString)
	} else {
		peerPadMagic = []byte(initiatorPadString)
	}
	peerKey, peerIV := hsKdf(peerPadMagic, peerSeed[:], !conn.isInitiator)
	rxBlock, err := aes.NewCipher(peerKey)
	if err != nil {
		return err
	}
	rxStream := cipher.NewCTR(rxBlock, peerIV)
	conn.rx = &cipher.StreamReader{S: rxStream, R: conn.Conn}
	hsHdr := make([]byte, hsLen)
	if _, err := io.ReadFull(conn, hsHdr[:]); err != nil {
		return err
	}

	// If the MAGIC_VALUE does not match, or the PADLEN value is greater than
	// MAX_PADDING, the party receiving it should close the connection
	// immediately.
	if peerMagic := binary.BigEndian.Uint32(hsHdr[0:4]); peerMagic != magicValue {
		return fmt.Errorf("invalid magic value: %x", peerMagic)
	}
	padLen = binary.BigEndian.Uint32(hsHdr[4:8])
	if padLen > maxPadding {
		return fmt.Errorf("padlen too long: %d", padLen)
	}

	// Otherwise, it should read the remaining PADLEN bytes of padding data
	// and discard them.
	tmp := make([]byte, padLen)
	if _, err := io.ReadFull(conn.Conn, tmp); err != nil { // Note: Skips AES.
		return err
	}

	// Derive the actual keys.
	if err := conn.kdf(seed[:], peerSeed[:]); err != nil {
		return err
	}

	return nil
}

func (conn *obfs2Conn) kdf(seed, peerSeed []byte) error {
	// Additional keys are then derived as:
	//
	//  INIT_SECRET = MAC("Initiator obfuscated data", INIT_SEED|RESP_SEED)
	//  RESP_SECRET = MAC("Responder obfuscated data", INIT_SEED|RESP_SEED)
	//  INIT_KEY = INIT_SECRET[:KEYLEN]
	//  INIT_IV = INIT_SECRET[KEYLEN:]
	//  RESP_KEY = RESP_SECRET[:KEYLEN]
	//  RESP_IV = RESP_SECRET[KEYLEN:]
	combSeed := make([]byte, 0, seedLen*2)
	if conn.isInitiator {
		combSeed = append(combSeed, seed...)
		combSeed = append(combSeed, peerSeed...)
	} else {
		combSeed = append(combSeed, peerSeed...)
		combSeed = append(combSeed, seed...)
	}

	initKey, initIV := hsKdf([]byte(initiatorKdfString), combSeed, true)
	initBlock, err := aes.NewCipher(initKey)
	if err != nil {
		return err
	}
	initStream := cipher.NewCTR(initBlock, initIV)

	respKey, respIV := hsKdf([]byte(responderKdfString), combSeed, false)
	respBlock, err := aes.NewCipher(respKey)
	if err != nil {
		return err
	}
	respStream := cipher.NewCTR(respBlock, respIV)

	if conn.isInitiator {
		conn.tx.S = initStream
		conn.rx.S = respStream
	} else {
		conn.tx.S = respStream
		conn.rx.S = initStream
	}

	return nil
}

func hsKdf(magic, seed []byte, isInitiator bool) (padKey, padIV []byte) {
	// The actual key/IV is derived in the form of:
	// m = MAC(magic, seed)
	// KEY = m[:KEYLEN]
	// IV = m[KEYLEN:]
	m := mac(magic, seed)
	padKey = m[:keyLen]
	padIV = m[keyLen:]

	return
}

func mac(s, x []byte) []byte {
	// H(x) is SHA256 of x.
	// MAC(s, x) = H(s | x | s)
	h := sha256.New()
	h.Write(s)
	h.Write(x)
	h.Write(s)
	return h.Sum(nil)
}

var _ base.ClientFactory = (*obfs2ClientFactory)(nil)
var _ base.ServerFactory = (*obfs2ServerFactory)(nil)
var _ base.Transport = (*Transport)(nil)
var _ net.Conn = (*obfs2Conn)(nil)
