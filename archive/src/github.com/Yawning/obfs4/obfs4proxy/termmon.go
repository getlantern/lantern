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

package main

import (
	"io"
	"io/ioutil"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"git.torproject.org/pluggable-transports/obfs4.git/common/log"
)

var termMonitorOSInit func(*termMonitor) error

type termMonitor struct {
	sigChan     chan os.Signal
	handlerChan chan int
	numHandlers int
}

func (m *termMonitor) onHandlerStart() {
	m.handlerChan <- 1
}

func (m *termMonitor) onHandlerFinish() {
	m.handlerChan <- -1
}

func (m *termMonitor) wait(termOnNoHandlers bool) os.Signal {
	// Block until a signal has been received, or (optionally) the
	// number of pending handlers has hit 0.  In the case of the
	// latter, treat it as if a SIGTERM has been received.
	for {
		select {
		case n := <-m.handlerChan:
			m.numHandlers += n
		case sig := <-m.sigChan:
			return sig
		}
		if termOnNoHandlers && m.numHandlers == 0 {
			return syscall.SIGTERM
		}
	}
}

func (m *termMonitor) termOnStdinClose() {
	_, err := io.Copy(ioutil.Discard, os.Stdin)

	// io.Copy() will return a nil on EOF, since reaching EOF is
	// expected behavior.  No matter what, if this unblocks, assume
	// that stdin is closed, and treat that as having received a
	// SIGTERM.
	log.Noticef("Stdin is closed or unreadable: %v", err)
	m.sigChan <- syscall.SIGTERM
}

func (m *termMonitor) termOnPPIDChange(ppid int) {
	// Under most if not all U*IX systems, the parent PID will change
	// to that of init once the parent dies.  There are several notable
	// exceptions (Slowlaris/Android), but the parent PID changes
	// under those platforms as well.
	//
	// Naturally we lose if the parent has died by the time when the
	// Getppid() call was issued in our parent, but, this is better
	// than nothing.
	const ppidPollInterval = 1 * time.Second
	for ppid == os.Getppid() {
		time.Sleep(ppidPollInterval)
	}

	// Treat the parent PID changing as the same as having received
	// a SIGTERM.
	log.Noticef("Parent pid changed: %d (was %d)", os.Getppid(), ppid)
	m.sigChan <- syscall.SIGTERM
}

func newTermMonitor() (m *termMonitor) {
	ppid := os.Getppid()
	m = new(termMonitor)
	m.sigChan = make(chan os.Signal)
	m.handlerChan = make(chan int)
	signal.Notify(m.sigChan, syscall.SIGINT, syscall.SIGTERM)

	// If tor supports feature #15435, we can use Stdin being closed as an
	// indication that tor has died, or wants the PT to shutdown for any
	// reason.
	if ptShouldExitOnStdinClose() {
		go m.termOnStdinClose()
	} else {
		// Instead of feature #15435, use various kludges and hacks:
		//  * Linux - Platform specific code that should always work.
		//  * Other U*IX - Somewhat generic code, that works unless the
		//    parent dies before the monitor is initialized.
		if termMonitorOSInit != nil {
			// Errors here are non-fatal, since it might still be
			// possible to fall back to a generic implementation.
			if err := termMonitorOSInit(m); err == nil {
				return
			}
		}
		if runtime.GOOS != "windows" {
			go m.termOnPPIDChange(ppid)
		}
	}
	return
}
