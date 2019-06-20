/*
 * Copyright (c) 2014-2015, Yawning Angel <yawning at torproject dot org>
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

// Go language Tor Pluggable Transport suite.  Works only as a managed
// client/server.
package main

import (
	"flag"
	"fmt"
	"io"
	golog "log"
	"net"
	"net/url"
	"os"
	"path"
	"sync"
	"syscall"

	"golang.org/x/net/proxy"

	"git.torproject.org/pluggable-transports/goptlib.git"
	"git.torproject.org/pluggable-transports/obfs4.git/common/log"
	"git.torproject.org/pluggable-transports/obfs4.git/common/socks5"
	"git.torproject.org/pluggable-transports/obfs4.git/transports"
	"git.torproject.org/pluggable-transports/obfs4.git/transports/base"
)

const (
	obfs4proxyVersion = "0.0.7-dev"
	obfs4proxyLogFile = "obfs4proxy.log"
	socksAddr         = "127.0.0.1:0"
)

var stateDir string
var termMon *termMonitor

func clientSetup() (launched bool, listeners []net.Listener) {
	ptClientInfo, err := pt.ClientSetup(transports.Transports())
	if err != nil {
		golog.Fatal(err)
	}

	ptClientProxy, err := ptGetProxy()
	if err != nil {
		golog.Fatal(err)
	} else if ptClientProxy != nil {
		ptProxyDone()
	}

	// Launch each of the client listeners.
	for _, name := range ptClientInfo.MethodNames {
		t := transports.Get(name)
		if t == nil {
			pt.CmethodError(name, "no such transport is supported")
			continue
		}

		f, err := t.ClientFactory(stateDir)
		if err != nil {
			pt.CmethodError(name, "failed to get ClientFactory")
			continue
		}

		ln, err := net.Listen("tcp", socksAddr)
		if err != nil {
			pt.CmethodError(name, err.Error())
			continue
		}

		go clientAcceptLoop(f, ln, ptClientProxy)
		pt.Cmethod(name, socks5.Version(), ln.Addr())

		log.Infof("%s - registered listener: %s", name, ln.Addr())

		listeners = append(listeners, ln)
		launched = true
	}
	pt.CmethodsDone()

	return
}

func clientAcceptLoop(f base.ClientFactory, ln net.Listener, proxyURI *url.URL) error {
	defer ln.Close()
	for {
		conn, err := ln.Accept()
		if err != nil {
			if e, ok := err.(net.Error); ok && !e.Temporary() {
				return err
			}
			continue
		}
		go clientHandler(f, conn, proxyURI)
	}
}

func clientHandler(f base.ClientFactory, conn net.Conn, proxyURI *url.URL) {
	defer conn.Close()
	termMon.onHandlerStart()
	defer termMon.onHandlerFinish()

	name := f.Transport().Name()

	// Read the client's SOCKS handshake.
	socksReq, err := socks5.Handshake(conn)
	if err != nil {
		log.Errorf("%s - client failed socks handshake: %s", name, err)
		return
	}
	addrStr := log.ElideAddr(socksReq.Target)

	// Deal with arguments.
	args, err := f.ParseArgs(&socksReq.Args)
	if err != nil {
		log.Errorf("%s(%s) - invalid arguments: %s", name, addrStr, err)
		socksReq.Reply(socks5.ReplyGeneralFailure)
		return
	}

	// Obtain the proxy dialer if any, and create the outgoing TCP connection.
	dialFn := proxy.Direct.Dial
	if proxyURI != nil {
		dialer, err := proxy.FromURL(proxyURI, proxy.Direct)
		if err != nil {
			// This should basically never happen, since config protocol
			// verifies this.
			log.Errorf("%s(%s) - failed to obtain proxy dialer: %s", name, addrStr, log.ElideError(err))
			socksReq.Reply(socks5.ReplyGeneralFailure)
			return
		}
		dialFn = dialer.Dial
	}
	remote, err := f.Dial("tcp", socksReq.Target, dialFn, args)
	if err != nil {
		log.Errorf("%s(%s) - outgoing connection failed: %s", name, addrStr, log.ElideError(err))
		socksReq.Reply(socks5.ErrorToReplyCode(err))
		return
	}
	defer remote.Close()
	err = socksReq.Reply(socks5.ReplySucceeded)
	if err != nil {
		log.Errorf("%s(%s) - SOCKS reply failed: %s", name, addrStr, log.ElideError(err))
		return
	}

	if err = copyLoop(conn, remote); err != nil {
		log.Warnf("%s(%s) - closed connection: %s", name, addrStr, log.ElideError(err))
	} else {
		log.Infof("%s(%s) - closed connection", name, addrStr)
	}

	return
}

func serverSetup() (launched bool, listeners []net.Listener) {
	ptServerInfo, err := pt.ServerSetup(transports.Transports())
	if err != nil {
		golog.Fatal(err)
	}

	for _, bindaddr := range ptServerInfo.Bindaddrs {
		name := bindaddr.MethodName
		t := transports.Get(name)
		if t == nil {
			pt.SmethodError(name, "no such transport is supported")
			continue
		}

		f, err := t.ServerFactory(stateDir, &bindaddr.Options)
		if err != nil {
			pt.SmethodError(name, err.Error())
			continue
		}

		ln, err := net.ListenTCP("tcp", bindaddr.Addr)
		if err != nil {
			pt.SmethodError(name, err.Error())
			continue
		}

		go serverAcceptLoop(f, ln, &ptServerInfo)
		if args := f.Args(); args != nil {
			pt.SmethodArgs(name, ln.Addr(), *args)
		} else {
			pt.SmethodArgs(name, ln.Addr(), nil)
		}

		log.Infof("%s - registered listener: %s", name, log.ElideAddr(ln.Addr().String()))

		listeners = append(listeners, ln)
		launched = true
	}
	pt.SmethodsDone()

	return
}

func serverAcceptLoop(f base.ServerFactory, ln net.Listener, info *pt.ServerInfo) error {
	defer ln.Close()
	for {
		conn, err := ln.Accept()
		if err != nil {
			if e, ok := err.(net.Error); ok && !e.Temporary() {
				return err
			}
			continue
		}
		go serverHandler(f, conn, info)
	}
}

func serverHandler(f base.ServerFactory, conn net.Conn, info *pt.ServerInfo) {
	defer conn.Close()
	termMon.onHandlerStart()
	defer termMon.onHandlerFinish()

	name := f.Transport().Name()
	addrStr := log.ElideAddr(conn.RemoteAddr().String())
	log.Infof("%s(%s) - new connection", name, addrStr)

	// Instantiate the server transport method and handshake.
	remote, err := f.WrapConn(conn)
	if err != nil {
		log.Warnf("%s(%s) - handshake failed: %s", name, addrStr, log.ElideError(err))
		return
	}

	// Connect to the orport.
	orConn, err := pt.DialOr(info, conn.RemoteAddr().String(), name)
	if err != nil {
		log.Errorf("%s(%s) - failed to connect to ORPort: %s", name, addrStr, log.ElideError(err))
		return
	}
	defer orConn.Close()

	if err = copyLoop(orConn, remote); err != nil {
		log.Warnf("%s(%s) - closed connection: %s", name, addrStr, log.ElideError(err))
	} else {
		log.Infof("%s(%s) - closed connection", name, addrStr)
	}

	return
}

func copyLoop(a net.Conn, b net.Conn) error {
	// Note: b is always the pt connection.  a is the SOCKS/ORPort connection.
	errChan := make(chan error, 2)

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer wg.Done()
		defer b.Close()
		defer a.Close()
		_, err := io.Copy(b, a)
		errChan <- err
	}()
	go func() {
		defer wg.Done()
		defer a.Close()
		defer b.Close()
		_, err := io.Copy(a, b)
		errChan <- err
	}()

	// Wait for both upstream and downstream to close.  Since one side
	// terminating closes the other, the second error in the channel will be
	// something like EINVAL (though io.Copy() will swallow EOF), so only the
	// first error is returned.
	wg.Wait()
	if len(errChan) > 0 {
		return <-errChan
	}

	return nil
}

func getVersion() string {
	return fmt.Sprintf("obfs4proxy-%s", obfs4proxyVersion)
}

func main() {
	// Initialize the termination state monitor as soon as possible.
	termMon = newTermMonitor()

	// Handle the command line arguments.
	_, execName := path.Split(os.Args[0])
	showVer := flag.Bool("version", false, "Print version and exit")
	logLevelStr := flag.String("logLevel", "ERROR", "Log level (ERROR/WARN/INFO/DEBUG)")
	enableLogging := flag.Bool("enableLogging", false, "Log to TOR_PT_STATE_LOCATION/"+obfs4proxyLogFile)
	unsafeLogging := flag.Bool("unsafeLogging", false, "Disable the address scrubber")
	flag.Parse()

	if *showVer {
		fmt.Printf("%s\n", getVersion())
		os.Exit(0)
	}
	if err := log.SetLogLevel(*logLevelStr); err != nil {
		golog.Fatalf("[ERROR]: %s - failed to set log level: %s", execName, err)
	}

	// Determine if this is a client or server, initialize the common state.
	var ptListeners []net.Listener
	launched := false
	isClient, err := ptIsClient()
	if err != nil {
		golog.Fatalf("[ERROR]: %s - must be run as a managed transport", execName)
	}
	if stateDir, err = pt.MakeStateDir(); err != nil {
		golog.Fatalf("[ERROR]: %s - No state directory: %s", execName, err)
	}
	if err = log.Init(*enableLogging, path.Join(stateDir, obfs4proxyLogFile), *unsafeLogging); err != nil {
		golog.Fatalf("[ERROR]: %s - failed to initialize logging", execName)
	}
	if err = transports.Init(); err != nil {
		log.Errorf("%s - failed to initialize transports: %s", execName, err)
		os.Exit(-1)
	}

	log.Noticef("%s - launched", getVersion())

	// Do the managed pluggable transport protocol configuration.
	if isClient {
		log.Infof("%s - initializing client transport listeners", execName)
		launched, ptListeners = clientSetup()
	} else {
		log.Infof("%s - initializing server transport listeners", execName)
		launched, ptListeners = serverSetup()
	}
	if !launched {
		// Initialization failed, the client or server setup routines should
		// have logged, so just exit here.
		os.Exit(-1)
	}

	log.Infof("%s - accepting connections", execName)
	defer func() {
		log.Noticef("%s - terminated", execName)
	}()

	// At this point, the pt config protocol is finished, and incoming
	// connections will be processed.  Wait till the parent dies
	// (immediate exit), a SIGTERM is received (immediate exit),
	// or a SIGINT is received.
	if sig := termMon.wait(false); sig == syscall.SIGTERM {
		return
	}

	// Ok, it was the first SIGINT, close all listeners, and wait till,
	// the parent dies, all the current connections are closed, or either
	// a SIGINT/SIGTERM is received, and exit.
	for _, ln := range ptListeners {
		ln.Close()
	}
	termMon.wait(true)
}
