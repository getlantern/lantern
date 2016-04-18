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

// Package obfs3 provides an implementation of the Tor Project's obfs3
// obfuscation protocol.
package obfs3

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"io"
	"net"
	"time"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/common/csrand"
	"git.torproject.org/pluggable-transports/obfs4.git/common/uniformdh"
	"git.torproject.org/pluggable-transports/obfs4.git/transports/base"
)

const (
	transportName = "obfs3"

	clientHandshakeTimeout = time.Duration(30) * time.Second
	serverHandshakeTimeout = time.Duration(30) * time.Second

	initiatorKdfString   = "Initiator obfuscated data"
	responderKdfString   = "Responder obfuscated data"
	initiatorMagicString = "Initiator magic"
	responderMagicString = "Responder magic"
	maxPadding           = 8194
	keyLen               = 16
)

// Transport is the obfs3 implementation of the base.Transport interface.
type Transport struct{}

// Name returns the name of the obfs3 transport protocol.
func (t *Transport) Name() string {
	return transportName
}

// ClientFactory returns a new obfs3ClientFactory instance.
func (t *Transport) ClientFactory(stateDir string) (base.ClientFactory, error) {
	cf := &obfs3ClientFactory{transport: t}
	return cf, nil
}

// ServerFactory returns a new obfs3ServerFactory instance.
func (t *Transport) ServerFactory(stateDir string, args *pt.Args) (base.ServerFactory, error) {
	sf := &obfs3ServerFactory{transport: t}
	return sf, nil
}

type obfs3ClientFactory struct {
	transport base.Transport
}

func (cf *obfs3ClientFactory) Transport() base.Transport {
	return cf.transport
}

func (cf *obfs3ClientFactory) ParseArgs(args *pt.Args) (interface{}, error) {
	return nil, nil
}

func (cf *obfs3ClientFactory) Dial(network, addr string, dialFn base.DialFunc, args interface{}) (net.Conn, error) {
	conn, err := dialFn(network, addr)
	if err != nil {
		return nil, err
	}
	dialConn := conn
	if conn, err = newObfs3ClientConn(conn); err != nil {
		dialConn.Close()
		return nil, err
	}
	return conn, nil
}

type obfs3ServerFactory struct {
	transport base.Transport
}

func (sf *obfs3ServerFactory) Transport() base.Transport {
	return sf.transport
}

func (sf *obfs3ServerFactory) Args() *pt.Args {
	return nil
}

func (sf *obfs3ServerFactory) WrapConn(conn net.Conn) (net.Conn, error) {
	return newObfs3ServerConn(conn)
}

type obfs3Conn struct {
	net.Conn

	isInitiator bool
	rxMagic     []byte
	txMagic     []byte
	rxBuf       *bytes.Buffer

	rx *cipher.StreamReader
	tx *cipher.StreamWriter
}

func newObfs3ClientConn(conn net.Conn) (c *obfs3Conn, err error) {
	// Initialize a client connection, and start the handshake timeout.
	c = &obfs3Conn{conn, true, nil, nil, new(bytes.Buffer), nil, nil}
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

func newObfs3ServerConn(conn net.Conn) (c *obfs3Conn, err error) {
	// Initialize a server connection, and start the handshake timeout.
	c = &obfs3Conn{conn, false, nil, nil, new(bytes.Buffer), nil, nil}
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

func (conn *obfs3Conn) handshake() error {
	// The party who opens the connection is the 'initiator'; the one who
	// accepts it is the 'responder'.  Each begins by generating a
	// UniformDH keypair, and a random number PADLEN in [0, MAX_PADDING/2].
	// Both parties then send:
	//
	//  PUB_KEY | WR(PADLEN)
	privateKey, err := uniformdh.GenerateKey(csrand.Reader)
	if err != nil {
		return err
	}
	padLen := csrand.IntRange(0, maxPadding/2)
	blob := make([]byte, uniformdh.Size+padLen)
	publicKey, err := privateKey.PublicKey.Bytes()
	if err != nil {
		return err
	}
	copy(blob[0:], publicKey)
	if err := csrand.Bytes(blob[uniformdh.Size:]); err != nil {
		return err
	}
	if _, err := conn.Conn.Write(blob); err != nil {
		return err
	}

	// Read the public key from the peer.
	rawPeerPublicKey := make([]byte, uniformdh.Size)
	if _, err := io.ReadFull(conn.Conn, rawPeerPublicKey); err != nil {
		return err
	}
	var peerPublicKey uniformdh.PublicKey
	if err := peerPublicKey.SetBytes(rawPeerPublicKey); err != nil {
		return err
	}

	// After retrieving the public key of the other end, each party
	// completes the DH key exchange and generates a shared-secret for the
	// session (named SHARED_SECRET).
	sharedSecret, err := uniformdh.Handshake(privateKey, &peerPublicKey)
	if err != nil {
		return err
	}
	if err := conn.kdf(sharedSecret); err != nil {
		return err
	}

	return nil
}

func (conn *obfs3Conn) kdf(sharedSecret []byte) error {
	// Using that shared-secret each party derives its encryption keys as
	// follows:
	//
	//   INIT_SECRET = HMAC(SHARED_SECRET, "Initiator obfuscated data")
	//   RESP_SECRET = HMAC(SHARED_SECRET, "Responder obfuscated data")
	//   INIT_KEY = INIT_SECRET[:KEYLEN]
	//   INIT_COUNTER = INIT_SECRET[KEYLEN:]
	//   RESP_KEY = RESP_SECRET[:KEYLEN]
	//   RESP_COUNTER = RESP_SECRET[KEYLEN:]
	initHmac := hmac.New(sha256.New, sharedSecret)
	initHmac.Write([]byte(initiatorKdfString))
	initSecret := initHmac.Sum(nil)
	initHmac.Reset()
	initHmac.Write([]byte(initiatorMagicString))
	initMagic := initHmac.Sum(nil)

	respHmac := hmac.New(sha256.New, sharedSecret)
	respHmac.Write([]byte(responderKdfString))
	respSecret := respHmac.Sum(nil)
	respHmac.Reset()
	respHmac.Write([]byte(responderMagicString))
	respMagic := respHmac.Sum(nil)

	// The INIT_KEY value keys a block cipher (in CTR mode) used to
	// encrypt values from initiator to responder thereafter.  The counter
	// mode's initial counter value is INIT_COUNTER.  The RESP_KEY value
	// keys a block cipher (in CTR mode) used to encrypt values from
	// responder to initiator thereafter.  That counter mode's initial
	// counter value is RESP_COUNTER.
	//
	// Note: To have this be the last place where the shared secret is used,
	// also generate the magic value to send/scan for here.
	initBlock, err := aes.NewCipher(initSecret[:keyLen])
	if err != nil {
		return err
	}
	initStream := cipher.NewCTR(initBlock, initSecret[keyLen:])

	respBlock, err := aes.NewCipher(respSecret[:keyLen])
	if err != nil {
		return err
	}
	respStream := cipher.NewCTR(respBlock, respSecret[keyLen:])

	if conn.isInitiator {
		conn.tx = &cipher.StreamWriter{S: initStream, W: conn.Conn}
		conn.rx = &cipher.StreamReader{S: respStream, R: conn.rxBuf}
		conn.txMagic = initMagic
		conn.rxMagic = respMagic
	} else {
		conn.tx = &cipher.StreamWriter{S: respStream, W: conn.Conn}
		conn.rx = &cipher.StreamReader{S: initStream, R: conn.rxBuf}
		conn.txMagic = respMagic
		conn.rxMagic = initMagic
	}

	return nil
}

func (conn *obfs3Conn) findPeerMagic() error {
	var hsBuf [maxPadding + sha256.Size]byte
	for {
		n, err := conn.Conn.Read(hsBuf[:])
		if err != nil {
			// Yes, Read can return partial data and an error, but continuing
			// past that is nonsensical.
			return err
		}
		conn.rxBuf.Write(hsBuf[:n])

		pos := bytes.Index(conn.rxBuf.Bytes(), conn.rxMagic)
		if pos == -1 {
			if conn.rxBuf.Len() >= maxPadding+sha256.Size {
				return errors.New("failed to find peer magic value")
			}
			continue
		} else if pos > maxPadding {
			return errors.New("peer sent too much pre-magic-padding")
		}

		// Discard the padding/MAC.
		pos += len(conn.rxMagic)
		_ = conn.rxBuf.Next(pos)

		return nil
	}
}

func (conn *obfs3Conn) Read(b []byte) (n int, err error) {
	// If this is the first time we read data post handshake, scan for the
	// magic value.
	if conn.rxMagic != nil {
		if err = conn.findPeerMagic(); err != nil {
			conn.Close()
			return
		}
		conn.rxMagic = nil
	}

	// If the handshake receive buffer is still present...
	if conn.rxBuf != nil {
		// And it is empty...
		if conn.rxBuf.Len() == 0 {
			// There is no more trailing data left from the handshake process,
			// so rewire the cipher.StreamReader to pull data from the network
			// instead of the temporary receive buffer.
			conn.rx.R = conn.Conn
			conn.rxBuf = nil
		}
	}

	return conn.rx.Read(b)
}

func (conn *obfs3Conn) Write(b []byte) (n int, err error) {
	// If this is the first time we write data post handshake, send the
	// padding/magic value.
	if conn.txMagic != nil {
		padLen := csrand.IntRange(0, maxPadding/2)
		blob := make([]byte, padLen+len(conn.txMagic))
		if err = csrand.Bytes(blob[:padLen]); err != nil {
			conn.Close()
			return
		}
		copy(blob[padLen:], conn.txMagic)
		if _, err = conn.Conn.Write(blob); err != nil {
			conn.Close()
			return
		}
		conn.txMagic = nil
	}

	return conn.tx.Write(b)
}

var _ base.ClientFactory = (*obfs3ClientFactory)(nil)
var _ base.ServerFactory = (*obfs3ServerFactory)(nil)
var _ base.Transport = (*Transport)(nil)
var _ net.Conn = (*obfs3Conn)(nil)
