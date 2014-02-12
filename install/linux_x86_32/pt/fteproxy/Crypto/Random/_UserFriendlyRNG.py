# -*- coding: utf-8 -*-
#
#  Random/_UserFriendlyRNG.py : A user-friendly random number generator
#
# Written in 2008 by Dwayne C. Litzenberger <dlitz@dlitz.net>
#
# ===================================================================
# The contents of this file are dedicated to the public domain.  To
# the extent that dedication to the public domain is not available,
# everyone is granted a worldwide, perpetual, royalty-free,
# non-exclusive license to exercise all rights associated with the
# contents of this file for any purpose whatsoever.
# No rights are reserved.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ===================================================================

__revision__ = "$Id$"

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *

import os
import threading
import struct
import time
from math import floor

from Crypto.Random import OSRNG
from Crypto.Random.Fortuna import FortunaAccumulator

class _EntropySource(object):
    def __init__(self, accumulator, src_num):
        self._fortuna = accumulator
        self._src_num = src_num
        self._pool_num = 0

    def feed(self, data):
        self._fortuna.add_random_event(self._src_num, self._pool_num, data)
        self._pool_num = (self._pool_num + 1) & 31

class _EntropyCollector(object):

    def __init__(self, accumulator):
        self._osrng = OSRNG.new()
        self._osrng_es = _EntropySource(accumulator, 255)
        self._time_es = _EntropySource(accumulator, 254)
        self._clock_es = _EntropySource(accumulator, 253)

    def reinit(self):
        # Add 256 bits to each of the 32 pools, twice.  (For a total of 16384
        # bits collected from the operating system.)
        for i in range(2):
            block = self._osrng.read(32*32)
            for p in range(32):
                self._osrng_es.feed(block[p*32:(p+1)*32])
            block = None
        self._osrng.flush()

    def collect(self):
        # Collect 64 bits of entropy from the operating system and feed it to Fortuna.
        self._osrng_es.feed(self._osrng.read(8))

        # Add the fractional part of time.time()
        t = time.time()
        self._time_es.feed(struct.pack("@I", int(2**30 * (t - floor(t)))))

        # Add the fractional part of time.clock()
        t = time.clock()
        self._clock_es.feed(struct.pack("@I", int(2**30 * (t - floor(t)))))


class _UserFriendlyRNG(object):

    def __init__(self):
        self.closed = False
        self._fa = FortunaAccumulator.FortunaAccumulator()
        self._ec = _EntropyCollector(self._fa)
        self.reinit()

    def reinit(self):
        """Initialize the random number generator and seed it with entropy from
        the operating system.
        """

        # Save the pid (helps ensure that Crypto.Random.atfork() gets called)
        self._pid = os.getpid()

        # Collect entropy from the operating system and feed it to
        # FortunaAccumulator
        self._ec.reinit()

        # Override FortunaAccumulator's 100ms minimum re-seed interval.  This
        # is necessary to avoid a race condition between this function and
        # self.read(), which that can otherwise cause forked child processes to
        # produce identical output.  (e.g. CVE-2013-1445)
        #
        # Note that if this function can be called frequently by an attacker,
        # (and if the bits from OSRNG are insufficiently random) it will weaken
        # Fortuna's ability to resist a state compromise extension attack.
        self._fa._forget_last_reseed()

    def close(self):
        self.closed = True
        self._osrng = None
        self._fa = None

    def flush(self):
        pass

    def read(self, N):
        """Return N bytes from the RNG."""
        if self.closed:
            raise ValueError("I/O operation on closed file")
        if not isinstance(N, (long, int)):
            raise TypeError("an integer is required")
        if N < 0:
            raise ValueError("cannot read to end of infinite stream")

        # Collect some entropy and feed it to Fortuna
        self._ec.collect()

        # Ask Fortuna to generate some bytes
        retval = self._fa.random_data(N)

        # Check that we haven't forked in the meantime.  (If we have, we don't
        # want to use the data, because it might have been duplicated in the
        # parent process.
        self._check_pid()

        # Return the random data.
        return retval

    def _check_pid(self):
        # Lame fork detection to remind developers to invoke Random.atfork()
        # after every call to os.fork().  Note that this check is not reliable,
        # since process IDs can be reused on most operating systems.
        #
        # You need to do Random.atfork() in the child process after every call
        # to os.fork() to avoid reusing PRNG state.  If you want to avoid
        # leaking PRNG state to child processes (for example, if you are using
        # os.setuid()) then you should also invoke Random.atfork() in the
        # *parent* process.
        if os.getpid() != self._pid:
            raise AssertionError("PID check failed. RNG must be re-initialized after fork(). Hint: Try Random.atfork()")


class _LockingUserFriendlyRNG(_UserFriendlyRNG):
    def __init__(self):
        self._lock = threading.Lock()
        _UserFriendlyRNG.__init__(self)

    def close(self):
        self._lock.acquire()
        try:
            return _UserFriendlyRNG.close(self)
        finally:
            self._lock.release()

    def reinit(self):
        self._lock.acquire()
        try:
            return _UserFriendlyRNG.reinit(self)
        finally:
            self._lock.release()

    def read(self, bytes):
        self._lock.acquire()
        try:
            return _UserFriendlyRNG.read(self, bytes)
        finally:
            self._lock.release()

class RNGFile(object):
    def __init__(self, singleton):
        self.closed = False
        self._singleton = singleton

    # PEP 343: Support for the "with" statement
    def __enter__(self):
        """PEP 343 support"""
    def __exit__(self):
        """PEP 343 support"""
        self.close()

    def close(self):
        # Don't actually close the singleton, just close this RNGFile instance.
        self.closed = True
        self._singleton = None

    def read(self, bytes):
        if self.closed:
            raise ValueError("I/O operation on closed file")
        return self._singleton.read(bytes)

    def flush(self):
        if self.closed:
            raise ValueError("I/O operation on closed file")

_singleton_lock = threading.Lock()
_singleton = None
def _get_singleton():
    global _singleton
    _singleton_lock.acquire()
    try:
        if _singleton is None:
            _singleton = _LockingUserFriendlyRNG()
        return _singleton
    finally:
        _singleton_lock.release()

def new():
    return RNGFile(_get_singleton())

def reinit():
    _get_singleton().reinit()

def get_random_bytes(n):
    """Return the specified number of cryptographically-strong random bytes."""
    return _get_singleton().read(n)

# vim:set ts=4 sw=4 sts=4 expandtab:
