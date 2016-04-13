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

// Package scramblesuit provides an implementation of the ScrambleSuit
// obfuscation protocol.  The implementation is client only.
package scramblesuit

import (
	"fmt"
	"net"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/transports/base"
)

const transportName = "scramblesuit"

// Transport is the ScrambleSuit implementation of the base.Transport interface.
type Transport struct{}

// Name returns the name of the ScrambleSuit transport protocol.
func (t *Transport) Name() string {
	return transportName
}

// ClientFactory returns a new ssClientFactory instance.
func (t *Transport) ClientFactory(stateDir string) (base.ClientFactory, error) {
	tStore, err := loadTicketStore(stateDir)
	if err != nil {
		return nil, err
	}
	cf := &ssClientFactory{transport: t, ticketStore: tStore}
	return cf, nil
}

// ServerFactory will one day return a new ssServerFactory instance.
func (t *Transport) ServerFactory(stateDir string, args *pt.Args) (base.ServerFactory, error) {
	// TODO: Fill this in eventually, though obfs4 is better.
	return nil, fmt.Errorf("server not supported")
}

type ssClientFactory struct {
	transport   base.Transport
	ticketStore *ssTicketStore
}

func (cf *ssClientFactory) Transport() base.Transport {
	return cf.transport
}

func (cf *ssClientFactory) ParseArgs(args *pt.Args) (interface{}, error) {
	return newClientArgs(args)
}

func (cf *ssClientFactory) Dial(network, addr string, dialFn base.DialFunc, args interface{}) (net.Conn, error) {
	// Validate args before opening outgoing connection.
	ca, ok := args.(*ssClientArgs)
	if !ok {
		return nil, fmt.Errorf("invalid argument type for args")
	}

	conn, err := dialFn(network, addr)
	if err != nil {
		return nil, err
	}
	dialConn := conn
	if conn, err = newScrambleSuitClientConn(conn, cf.ticketStore, ca); err != nil {
		dialConn.Close()
		return nil, err
	}
	return conn, nil
}

var _ base.ClientFactory = (*ssClientFactory)(nil)
var _ base.Transport = (*Transport)(nil)
