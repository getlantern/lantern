#
#  Random/OSRNG/rng_base.py : Base class for OSRNG
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

class BaseRNG(object):

    def __init__(self):
        self.closed = False
        self._selftest()

    def __del__(self):
        self.close()

    def _selftest(self):
        # Test that urandom can return data
        data = self.read(16)
        if len(data) != 16:
            raise AssertionError("read truncated")

        # Test that we get different data every time (if we don't, the RNG is
        # probably malfunctioning)
        data2 = self.read(16)
        if data == data2:
            raise AssertionError("OS RNG returned duplicate data")

    # PEP 343: Support for the "with" statement
    def __enter__(self):
        pass
    def __exit__(self):
        """PEP 343 support"""
        self.close()

    def close(self):
        if not self.closed:
            self._close()
        self.closed = True

    def flush(self):
        pass

    def read(self, N=-1):
        """Return N bytes from the RNG."""
        if self.closed:
            raise ValueError("I/O operation on closed file")
        if not isinstance(N, (long, int)):
            raise TypeError("an integer is required")
        if N < 0:
            raise ValueError("cannot read to end of infinite stream")
        elif N == 0:
            return ""
        data = self._read(N)
        if len(data) != N:
            raise AssertionError("%s produced truncated output (requested %d, got %d)" % (self.name, N, len(data)))
        return data

    def _close(self):
        raise NotImplementedError("child class must implement this")

    def _read(self, N):
        raise NotImplementedError("child class must implement this")


# vim:set ts=4 sw=4 sts=4 expandtab:
