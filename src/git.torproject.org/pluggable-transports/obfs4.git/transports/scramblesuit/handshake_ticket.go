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
	"encoding/base32"
	"encoding/json"
	"errors"
	"fmt"
	"hash"
	"io/ioutil"
	"net"
	"os"
	"path"
	"strconv"
	"sync"
	"time"

	"git.torproject.org/pluggable-transports/obfs4.git/common/csrand"
)

const (
	ticketFile = "scramblesuit_tickets.json"

	ticketKeyLength = 32
	ticketLength    = 112
	ticketLifetime  = 60 * 60 * 24 * 7

	ticketMinPadLength = 0
	ticketMaxPadLength = 1388
)

var (
	errInvalidTicket = errors.New("scramblesuit: invalid serialized ticket")
)

type ssTicketStore struct {
	sync.Mutex

	filePath string
	store    map[string]*ssTicket
}

type ssTicket struct {
	key      [ticketKeyLength]byte
	ticket   [ticketLength]byte
	issuedAt int64
}

type ssTicketJSON struct {
	KeyTicket string `json:"key-ticket"`
	IssuedAt  int64  `json:"issuedAt"`
}

func (t *ssTicket) isValid() bool {
	return t.issuedAt+ticketLifetime > time.Now().Unix()
}

func newTicket(raw []byte) (*ssTicket, error) {
	if len(raw) != ticketKeyLength+ticketLength {
		return nil, errInvalidTicket
	}
	t := &ssTicket{issuedAt: time.Now().Unix()}
	copy(t.key[:], raw[0:])
	copy(t.ticket[:], raw[ticketKeyLength:])
	return t, nil
}

func (s *ssTicketStore) storeTicket(addr net.Addr, rawT []byte) {
	t, err := newTicket(rawT)
	if err != nil {
		// Silently ignore ticket store failures.
		return
	}

	s.Lock()
	defer s.Unlock()

	// Add the ticket to the map, and checkpoint to disk.  Serialization errors
	// are ignored because the handshake code will just use UniformDH if a
	// ticket is not available.
	s.store[addr.String()] = t
	s.serialize()
}

func (s *ssTicketStore) getTicket(addr net.Addr) (*ssTicket, error) {
	aStr := addr.String()

	s.Lock()
	defer s.Unlock()

	t, ok := s.store[aStr]
	if ok && t != nil {
		// Tickets are one use only, so remove tickets from the map, and
		// checkpoint the map to disk.
		delete(s.store, aStr)
		err := s.serialize()
		if !t.isValid() {
			// Expired ticket, ignore it.
			return nil, err
		}
		return t, err
	}

	// No ticket was found, that's fine.
	return nil, nil
}

func (s *ssTicketStore) serialize() error {
	encMap := make(map[string]*ssTicketJSON)
	for k, v := range s.store {
		kt := make([]byte, 0, ticketKeyLength+ticketLength)
		kt = append(kt, v.key[:]...)
		kt = append(kt, v.ticket[:]...)
		ktStr := base32.StdEncoding.EncodeToString(kt)
		jsonObj := &ssTicketJSON{KeyTicket: ktStr, IssuedAt: v.issuedAt}
		encMap[k] = jsonObj
	}
	jsonStr, err := json.Marshal(encMap)
	if err != nil {
		return err
	}
	return ioutil.WriteFile(s.filePath, jsonStr, 0600)
}

func loadTicketStore(stateDir string) (*ssTicketStore, error) {
	fPath := path.Join(stateDir, ticketFile)
	s := &ssTicketStore{filePath: fPath}
	s.store = make(map[string]*ssTicket)

	f, err := ioutil.ReadFile(fPath)
	if err != nil {
		// No ticket store is fine.
		if os.IsNotExist(err) {
			return s, nil
		}

		// But a file read error is not.
		return nil, err
	}

	encMap := make(map[string]*ssTicketJSON)
	if err = json.Unmarshal(f, &encMap); err != nil {
		return nil, fmt.Errorf("failed to load ticket store '%s': '%s'", fPath, err)
	}
	for k, v := range encMap {
		raw, err := base32.StdEncoding.DecodeString(v.KeyTicket)
		if err != nil || len(raw) != ticketKeyLength+ticketLength {
			// Just silently skip corrupted tickets.
			continue
		}
		t := &ssTicket{issuedAt: v.IssuedAt}
		if !t.isValid() {
			// Just ignore expired tickets.
			continue
		}
		copy(t.key[:], raw[0:])
		copy(t.ticket[:], raw[ticketKeyLength:])
		s.store[k] = t
	}
	return s, nil
}

type ssTicketClientHandshake struct {
	mac    hash.Hash
	ticket *ssTicket
	padLen int
}

func (hs *ssTicketClientHandshake) generateHandshake() ([]byte, error) {
	var buf bytes.Buffer
	hs.mac.Reset()

	// The client handshake is T | P | M | MAC(T | P | M | E)
	hs.mac.Write(hs.ticket.ticket[:])
	m := hs.mac.Sum(nil)[:macLength]
	p, err := makePad(hs.padLen)
	if err != nil {
		return nil, err
	}

	// Write T, P, M.
	buf.Write(hs.ticket.ticket[:])
	buf.Write(p)
	buf.Write(m)

	// Calculate and write the MAC.
	e := []byte(strconv.FormatInt(getEpochHour(), 10))
	hs.mac.Write(p)
	hs.mac.Write(m)
	hs.mac.Write(e)
	buf.Write(hs.mac.Sum(nil)[:macLength])

	hs.mac.Reset()
	return buf.Bytes(), nil
}

func newTicketClientHandshake(mac hash.Hash, ticket *ssTicket) *ssTicketClientHandshake {
	hs := &ssTicketClientHandshake{mac: mac, ticket: ticket}
	hs.padLen = csrand.IntRange(ticketMinPadLength, ticketMaxPadLength)
	return hs
}
