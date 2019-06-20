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

// Package log implements a simple set of leveled logging wrappers around the
// standard log package.
package log

import (
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"os"
	"strings"
)

const (
	elidedAddr = "[scrubbed]"

	// LevelError is the ERROR log level (NOTICE/ERROR).
	LevelError = iota

	// LevelWarn is the WARN log level,  (NOTICE/ERROR/WARN).
	LevelWarn

	// LevelInfo is the INFO log level, (NOTICE/ERROR/WARN/INFO).
	LevelInfo

	// LevelDebug is the DEBUG log level, (NOTICE/ERROR/WARN/INFO/DEBUG).
	LevelDebug
)

var logLevel = LevelInfo
var enableLogging bool
var unsafeLogging bool

// Init initializes logging with the given path, and log safety options.
func Init(enable bool, logFilePath string, unsafe bool) error {
	if enable {
		f, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return err
		}
		log.SetOutput(f)
	} else {
		log.SetOutput(ioutil.Discard)
	}
	enableLogging = enable
	return nil
}

// Enabled returns if logging is enabled.
func Enabled() bool {
	return enableLogging
}

// Unsafe returns if unsafe logging is allowed (the caller MAY skip eliding
// addresses and other bits of sensitive information).
func Unsafe() bool {
	return unsafeLogging
}

// Level returns the current log level.
func Level() int {
	return logLevel
}

// SetLogLevel sets the log level to the value indicated by the given string
// (case-insensitive).
func SetLogLevel(logLevelStr string) error {
	switch strings.ToUpper(logLevelStr) {
	case "ERROR":
		logLevel = LevelError
	case "WARN":
		logLevel = LevelWarn
	case "INFO":
		logLevel = LevelInfo
	case "DEBUG":
		logLevel = LevelDebug
	default:
		return fmt.Errorf("invalid log level '%s'", logLevelStr)
	}
	return nil
}

// Noticef logs the given format string/arguments at the NOTICE log level.
// Unless logging is disabled, Noticef logs are always emitted.
func Noticef(format string, a ...interface{}) {
	if enableLogging {
		msg := fmt.Sprintf(format, a...)
		log.Print("[NOTICE]: " + msg)
	}
}

// Errorf logs the given format string/arguments at the ERROR log level.
func Errorf(format string, a ...interface{}) {
	if enableLogging && logLevel >= LevelError {
		msg := fmt.Sprintf(format, a...)
		log.Print("[ERROR]: " + msg)
	}
}

// Warnf logs the given format string/arguments at the WARN log level.
func Warnf(format string, a ...interface{}) {
	if enableLogging && logLevel >= LevelWarn {
		msg := fmt.Sprintf(format, a...)
		log.Print("[WARN]: " + msg)
	}
}

// Infof logs the given format string/arguments at the INFO log level.
func Infof(format string, a ...interface{}) {
	if enableLogging && logLevel >= LevelInfo {
		msg := fmt.Sprintf(format, a...)
		log.Print("[INFO]: " + msg)
	}
}

// Debugf logs the given format string/arguments at the DEBUG log level.
func Debugf(format string, a ...interface{}) {
	if enableLogging && logLevel >= LevelDebug {
		msg := fmt.Sprintf(format, a...)
		log.Print("[DEBUG]: " + msg)
	}
}

// ElideError transforms the string representation of the provided error
// based on the unsafeLogging setting.  Callers that wish to log errors
// returned from Go's net package should use ElideError to sanitize the
// contents first.
func ElideError(err error) string {
	// Go's net package is somewhat rude and includes IP address and port
	// information in the string representation of net.Errors.  Figure out if
	// this is the case here, and sanitize the error messages as needed.
	if unsafeLogging {
		return err.Error()
	}

	// If err is not a net.Error, just return the string representation,
	// presumably transport authors know what they are doing.
	netErr, ok := err.(net.Error)
	if !ok {
		return err.Error()
	}

	switch t := netErr.(type) {
	case *net.AddrError:
		return t.Err + " " + elidedAddr
	case *net.DNSError:
		return "lookup " + elidedAddr + " on " + elidedAddr + ": " + t.Err
	case *net.InvalidAddrError:
		return "invalid address error"
	case *net.UnknownNetworkError:
		return "unknown network " + elidedAddr
	case *net.OpError:
		return t.Op + ": " + t.Err.Error()
	default:
		// For unknown error types, do the conservative thing and only log the
		// type of the error instead of assuming that the string representation
		// does not contain sensitive information.
		return fmt.Sprintf("network error: <%T>", t)
	}
}

// ElideAddr transforms the string representation of the provided address based
// on the unsafeLogging setting.  Callers that wish to log IP addreses should
// use ElideAddr to sanitize the contents first.
func ElideAddr(addrStr string) string {
	if unsafeLogging {
		return addrStr
	}

	// Only scrub off the address so that it's easier to track connections
	// in logs by looking at the port.
	if _, port, err := net.SplitHostPort(addrStr); err == nil {
		return elidedAddr + ":" + port
	}
	return elidedAddr
}
