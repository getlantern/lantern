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

package scramblesuit

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base32"
	"encoding/binary"
	"errors"
	"fmt"
	"hash"
	"io"
	"net"
	"time"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/common/csrand"
	"git.torproject.org/pluggable-transports/obfs4.git/common/drbg"
	"git.torproject.org/pluggable-transports/obfs4.git/common/probdist"
	"git.torproject.org/pluggable-transports/obfs4.git/common/uniformdh"
)

const (
	passwordArg = "password"

	maxSegmentLength       = 1448
	maxPayloadLength       = 1427
	sharedSecretLength     = 160 / 8 // k_B
	clientHandshakeTimeout = time.Duration(60) * time.Second

	minLenDistLength = 21
	maxLenDistLength = maxSegmentLength

	keyLength = 32 + 8 + 32

	pktPrngSeedLength = 32
	pktOverhead       = macLength + pktHdrLength
	pktHdrLength      = 2 + 2 + 1
	pktPayload        = 1
	pktNewTicket      = 1 << 1
	pktPrngSeed       = 1 << 2
)

var (
	// ErrNotSupported is the error returned for a unsupported operation.
	ErrNotSupported = errors.New("scramblesuit: operation not supported")

	// ErrInvalidPacket is the error returned when a invalid packet is received.
	ErrInvalidPacket = errors.New("scramblesuit: invalid packet")

	zeroPadBytes [maxPayloadLength]byte
)

type ssSharedSecret [sharedSecretLength]byte

type ssClientArgs struct {
	kB         *ssSharedSecret
	sessionKey *uniformdh.PrivateKey
}

func newClientArgs(args *pt.Args) (ca *ssClientArgs, err error) {
	ca = &ssClientArgs{}
	if ca.kB, err = parsePasswordArg(args); err != nil {
		return nil, err
	}

	// Generate the client keypair before opening a connection since the time
	// taken is visible to an adversary.  This key might not end up being used
	// if a session ticket is present, but this doesn't take that long.
	if ca.sessionKey, err = uniformdh.GenerateKey(csrand.Reader); err != nil {
		return nil, err
	}
	return
}

func parsePasswordArg(args *pt.Args) (*ssSharedSecret, error) {
	str, ok := args.Get(passwordArg)
	if !ok {
		return nil, fmt.Errorf("missing argument '%s'", passwordArg)
	}

	// To match the obfsproxy behavior, 'str' should contain a Base32 encoded
	// shared secret (k_B) used for handshaking.
	decoded, err := base32.StdEncoding.DecodeString(str)
	if err != nil {
		return nil, fmt.Errorf("failed to decode password: %s", err)
	}
	if len(decoded) != sharedSecretLength {
		return nil, fmt.Errorf("password length %d is invalid", len(decoded))
	}
	ss := new(ssSharedSecret)
	copy(ss[:], decoded)
	return ss, nil
}

type ssCryptoState struct {
	s   cipher.Stream
	mac hash.Hash
}

func newCryptoState(aesKey []byte, ivPrefix []byte, macKey []byte) (*ssCryptoState, error) {
	// The ScrambleSuit CTR-AES256 link crypto uses an 8 byte prefix from the
	// KDF, and a 64 bit counter initialized to 1 as the IV.  The initial value
	// of the counter isn't documented in the spec either.
	var initialCtr = []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01}
	iv := make([]byte, 0, aes.BlockSize)
	iv = append(iv, ivPrefix...)
	iv = append(iv, initialCtr...)
	b, err := aes.NewCipher(aesKey)
	if err != nil {
		return nil, err
	}
	s := cipher.NewCTR(b, iv)
	mac := hmac.New(sha256.New, macKey)
	return &ssCryptoState{s: s, mac: mac}, nil
}

type ssConn struct {
	net.Conn

	isServer bool

	lenDist              *probdist.WeightedDist
	receiveBuffer        *bytes.Buffer
	receiveDecodedBuffer *bytes.Buffer
	receiveState         ssRxState

	txCrypto *ssCryptoState
	rxCrypto *ssCryptoState

	ticketStore *ssTicketStore
}

type ssRxState struct {
	mac []byte
	hdr []byte

	totalLen   int
	payloadLen int
}

func (conn *ssConn) Read(b []byte) (n int, err error) {
	// If the receive payload buffer is empty, consume data off the network.
	for conn.receiveDecodedBuffer.Len() == 0 {
		if err = conn.readPackets(); err != nil {
			break
		}
	}

	// Service the read request using buffered payload.
	if conn.receiveDecodedBuffer.Len() > 0 {
		n, _ = conn.receiveDecodedBuffer.Read(b)
	}
	return
}

func (conn *ssConn) Write(b []byte) (n int, err error) {
	var frameBuf bytes.Buffer
	p := b
	toSend := len(p)

	for toSend > 0 {
		// Send as much payload as will fit into each frame as possible.
		wrLen := len(p)
		if wrLen > maxPayloadLength {
			wrLen = maxPayloadLength
		}
		payload := p[:wrLen]
		if err = conn.makePacket(&frameBuf, pktPayload, payload, 0); err != nil {
			return 0, err
		}

		toSend -= wrLen
		p = p[wrLen:]
		n += wrLen
	}

	// Pad out the burst as appropriate.
	if err = conn.padBurst(&frameBuf, conn.lenDist.Sample()); err != nil {
		return 0, err
	}

	// Write and return.
	_, err = conn.Conn.Write(frameBuf.Bytes())
	return
}

func (conn *ssConn) SetDeadline(t time.Time) error {
	return ErrNotSupported
}

func (conn *ssConn) SetReadDeadline(t time.Time) error {
	return ErrNotSupported
}

func (conn *ssConn) SetWriteDeadline(t time.Time) error {
	return ErrNotSupported
}

func (conn *ssConn) makePacket(w io.Writer, pktType byte, data []byte, padLen int) error {
	payloadLen := len(data)
	totalLen := payloadLen + padLen
	if totalLen > maxPayloadLength {
		panic(fmt.Sprintf("BUG: makePacket() len(data) + padLen > maxPayloadLength: %d + %d > %d", len(data), padLen, maxPayloadLength))
	}

	// Build the packet header (total length, payload length, flags),
	// and append the payload and padding.
	pkt := make([]byte, pktHdrLength, pktHdrLength+payloadLen+padLen)
	binary.BigEndian.PutUint16(pkt[0:], uint16(totalLen))
	binary.BigEndian.PutUint16(pkt[2:], uint16(payloadLen))
	pkt[4] = pktType
	pkt = append(pkt, data...)
	pkt = append(pkt, zeroPadBytes[:padLen]...)

	// Encrypt the packet, and calculate the MAC.
	conn.txCrypto.s.XORKeyStream(pkt, pkt)
	conn.txCrypto.mac.Reset()
	conn.txCrypto.mac.Write(pkt)
	mac := conn.txCrypto.mac.Sum(nil)[:macLength]

	// Write out MAC | Packet.  Note that this does not go onto the network
	// yet, as w is a byte.Buffer (This is done so each call to conn.Write()
	// gets padding added).
	if _, err := w.Write(mac); err != nil {
		return err
	}
	_, err := w.Write(pkt)
	return err
}

func (conn *ssConn) readPackets() error {
	// Consume and buffer up to 1 MSS worth of data.
	var buf [maxSegmentLength]byte
	rdLen, rdErr := conn.Conn.Read(buf[:])
	conn.receiveBuffer.Write(buf[:rdLen])

	// Process incoming packets incrementally.  conn.receiveState stores
	// the results of partial processing.
	for conn.receiveBuffer.Len() > 0 {
		if conn.receiveState.mac == nil {
			// Read and store the packet MAC.
			if conn.receiveBuffer.Len() < macLength {
				break
			}
			mac := make([]byte, macLength)
			conn.receiveBuffer.Read(mac)
			conn.receiveState.mac = mac
		}

		if conn.receiveState.hdr == nil {
			// Read and store the packet header.
			if conn.receiveBuffer.Len() < pktHdrLength {
				break
			}
			hdr := make([]byte, pktHdrLength)
			conn.receiveBuffer.Read(hdr)

			// Add the encrypted packet header to the HMAC instance, and then
			// decrypt it so that the length of the packet can be determined.
			conn.rxCrypto.mac.Reset()
			conn.rxCrypto.mac.Write(hdr)
			conn.rxCrypto.s.XORKeyStream(hdr, hdr)

			// Store the plaintext packet header, and host byte order length
			// values.
			totalLen := int(binary.BigEndian.Uint16(hdr[0:]))
			payloadLen := int(binary.BigEndian.Uint16(hdr[2:]))
			if payloadLen > totalLen || totalLen > maxPayloadLength {
				return ErrInvalidPacket
			}
			conn.receiveState.hdr = hdr
			conn.receiveState.totalLen = totalLen
			conn.receiveState.payloadLen = payloadLen
		}

		var data []byte
		if conn.receiveState.totalLen > 0 {
			// If the packet actually has payload (including padding), read,
			// digest and decrypt it.
			if conn.receiveBuffer.Len() < conn.receiveState.totalLen {
				break
			}
			data = make([]byte, conn.receiveState.totalLen)
			conn.receiveBuffer.Read(data)
			conn.rxCrypto.mac.Write(data)
			conn.rxCrypto.s.XORKeyStream(data, data)
		}

		// Authenticate the packet, by comparing the received MAC with the one
		// calculated over the ciphertext consumed off the network.
		cmpMAC := conn.rxCrypto.mac.Sum(nil)[:macLength]
		if !hmac.Equal(cmpMAC, conn.receiveState.mac[:]) {
			return ErrInvalidPacket
		}

		// Based on the packet flags, do something useful with the payload.
		data = data[:conn.receiveState.payloadLen]
		switch conn.receiveState.hdr[4] {
		case pktPayload:
			// User data, write it into the decoded payload buffer so that Read
			// calls can be serviced.
			conn.receiveDecodedBuffer.Write(data)
		case pktNewTicket:
			// New Session Ticket to be used for future handshakes, store it in
			// the Session Ticket store.
			if conn.isServer || len(data) != ticketKeyLength+ticketLength {
				return ErrInvalidPacket
			}
			conn.ticketStore.storeTicket(conn.RemoteAddr(), data)
		case pktPrngSeed:
			// New PRNG_SEED for the protocol polymorphism.  Regenerate the
			// length obfuscation probability distribution.
			if conn.isServer || len(data) != pktPrngSeedLength {
				return ErrInvalidPacket
			}
			seed, err := drbg.SeedFromBytes(data)
			if err != nil {
				return ErrInvalidPacket
			}
			conn.lenDist.Reset(seed)
		default:
			return ErrInvalidPacket
		}

		// Done processing a packet, clear the partial state.
		conn.receiveState.mac = nil
		conn.receiveState.hdr = nil
		conn.receiveState.totalLen = 0
		conn.receiveState.payloadLen = 0
	}
	return rdErr
}

func (conn *ssConn) clientHandshake(kB *ssSharedSecret, sessionKey *uniformdh.PrivateKey) error {
	if conn.isServer {
		return fmt.Errorf("clientHandshake called on server connection")
	}

	// Query the Session Ticket store to see if there is a stored session
	// ticket.
	ticket, err := conn.ticketStore.getTicket(conn.RemoteAddr())
	if err != nil {
		return err
	} else if ticket != nil {
		// Ok, there is an existing ticket, so attempt to do a Session Ticket
		// handshake.  Until we write to the network, failures are non-fatal as
		// we can transition gracefully into doing a UniformDH handshake.

		// Derive the keys from the prestored master key received with the
		// ticket.  This is done before the actual handshake since the
		// handshake uses the outgoing HMAC-SHA256-128 key for authentication.
		if err = conn.initCrypto(ticket.key[:]); err != nil {
			goto handshakeUDH
		}

		// Generate and send the ticket handshake.  There is no response, since
		// both sides have the keying material.
		hs := newTicketClientHandshake(conn.txCrypto.mac, ticket)
		blob, err := hs.generateHandshake()
		if err != nil {
			goto handshakeUDH
		}
		if _, err = conn.Conn.Write(blob); err != nil {
			return err
		}
		return nil
	}

handshakeUDH:
	// No session ticket, so take the slow path and do a UniformDH based
	// handshake.

	// Generate and send the client handshake.
	hs := newDHClientHandshake(kB, sessionKey)
	blob, err := hs.generateHandshake()
	if err != nil {
		return err
	}
	if _, err = conn.Conn.Write(blob); err != nil {
		return err
	}

	// Consume the server handshake.  Since we don't actually know the length
	// of the respose, we need to consume data off the network till we either
	// find the tail marker + MAC digest indicating that a handshake response
	// has been received, or the maximum handshake size passes without a valid
	// response.
	var hsBuf [maxHandshakeLength]byte
	for {
		var n int
		if n, err = conn.Conn.Read(hsBuf[:]); err != nil {
			return err
		}
		conn.receiveBuffer.Write(hsBuf[:n])

		// Attempt to process all the data seen so far as a response.
		var seed []byte
		n, seed, err = hs.parseServerHandshake(conn.receiveBuffer.Bytes())
		if err == errMarkNotFoundYet {
			// No response found yet, keep trying.
			continue
		} else if err != nil {
			return err
		}

		// Ok, done processing the handshake, discard the response, and do the
		// key derivation based off the calculated shared secret.
		_ = conn.receiveBuffer.Next(n)
		err = conn.initCrypto(seed)
		return err
	}
}

func (conn *ssConn) initCrypto(seed []byte) error {
	// Use HKDF-SHA256 (Expand only, no Extract) to generate session keys from
	// initial keying material.
	okm := hkdfExpand(sha256.New, seed, nil, kdfSecretLength)
	var err error
	conn.txCrypto, err = newCryptoState(okm[0:32], okm[32:40], okm[80:112])
	if err != nil {
		return err
	}
	conn.rxCrypto, err = newCryptoState(okm[40:72], okm[72:80], okm[112:144])
	if err != nil {
		return err
	}
	return nil
}

func (conn *ssConn) padBurst(burst *bytes.Buffer, sampleLen int) error {
	// Burst contains the fully encrypted+MACed outgoing payload that will be
	// written to the network.  Pad it out so that the last segment (based on
	// the ScrambleSuit MTU) is sampleLen bytes.

	dataLen := burst.Len() % maxSegmentLength
	padLen := 0
	if sampleLen >= dataLen {
		padLen = sampleLen - dataLen
	} else {
		padLen = (maxSegmentLength - dataLen) + sampleLen
	}
	if padLen < pktOverhead {
		// The padLen is less than the MAC + packet header in length, so
		// two packets are required.
		padLen += maxSegmentLength
	}

	if padLen == 0 {
		return nil
	}
	if padLen > maxSegmentLength {
		// Note: packetmorpher.py: getPadding is slightly wrong and only
		// accounts for one of the two packet headers.
		if err := conn.makePacket(burst, pktPayload, nil, 700-pktOverhead); err != nil {
			return err
		}
		return conn.makePacket(burst, pktPayload, nil, padLen-(700+2*pktOverhead))
	}
	return conn.makePacket(burst, pktPayload, nil, padLen-pktOverhead)
}

func newScrambleSuitClientConn(conn net.Conn, tStore *ssTicketStore, ca *ssClientArgs) (net.Conn, error) {
	// At this point we have kB and our session key, so we can directly
	// start handshaking and seeing what happens.

	// Seed the initial polymorphism distribution.
	seed, err := drbg.NewSeed()
	if err != nil {
		return nil, err
	}
	dist := probdist.New(seed, minLenDistLength, maxLenDistLength, true)

	// Allocate the client structure.
	c := &ssConn{conn, false, dist, bytes.NewBuffer(nil), bytes.NewBuffer(nil), ssRxState{}, nil, nil, tStore}

	// Start the handshake timeout.
	deadline := time.Now().Add(clientHandshakeTimeout)
	if err := conn.SetDeadline(deadline); err != nil {
		return nil, err
	}

	// Attempt to handshake.
	if err := c.clientHandshake(ca.kB, ca.sessionKey); err != nil {
		return nil, err
	}

	// Stop the handshake timeout.
	if err := conn.SetDeadline(time.Time{}); err != nil {
		return nil, err
	}

	return c, nil
}
