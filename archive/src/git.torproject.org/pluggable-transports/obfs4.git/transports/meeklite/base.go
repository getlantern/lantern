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

// Package meeklite provides an implementation of the Meek circumvention
// protocol.  Only a client implementation is provided, and no effort is
// made to normalize the TLS fingerprint.
//
// It borrows quite liberally from the real meek-client code.
package meeklite

import (
	"fmt"
	"net"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/transports/base"
)

const transportName = "meek_lite"

// Transport is the Meek implementation of the base.Transport interface.
type Transport struct{}

// Name returns the name of the Meek transport protocol.
func (t *Transport) Name() string {
	return transportName
}

// ClientFactory returns a new meekClientFactory instance.
func (t *Transport) ClientFactory(stateDir string) (base.ClientFactory, error) {
	cf := &meekClientFactory{transport: t}
	return cf, nil
}

// ServerFactory will one day return a new meekServerFactory instance.
func (t *Transport) ServerFactory(stateDir string, args *pt.Args) (base.ServerFactory, error) {
	// TODO: Fill this in eventually, though for servers people should
	// just use the real thing.
	return nil, fmt.Errorf("server not supported")
}

type meekClientFactory struct {
	transport base.Transport
}

func (cf *meekClientFactory) Transport() base.Transport {
	return cf.transport
}

func (cf *meekClientFactory) ParseArgs(args *pt.Args) (interface{}, error) {
	return newClientArgs(args)
}

func (cf *meekClientFactory) Dial(network, addr string, dialFn base.DialFunc, args interface{}) (net.Conn, error) {
	// Validate args before opening outgoing connection.
	ca, ok := args.(*meekClientArgs)
	if !ok {
		return nil, fmt.Errorf("invalid argument type for args")
	}

	return newMeekConn(network, addr, dialFn, ca)
}

var _ base.ClientFactory = (*meekClientFactory)(nil)
var _ base.Transport = (*Transport)(nil)
