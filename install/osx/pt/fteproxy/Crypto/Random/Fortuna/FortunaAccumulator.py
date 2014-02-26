# -*- coding: ascii -*-
#
#  FortunaAccumulator.py : Fortuna's internal accumulator
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
from Crypto.Util.py3compat import *
    
from binascii import b2a_hex
import time
import warnings

from Crypto.pct_warnings import ClockRewindWarning
import SHAd256

import FortunaGenerator

class FortunaPool(object):
    """Fortuna pool type

    This object acts like a hash object, with the following differences:

        - It keeps a count (the .length attribute) of the number of bytes that
          have been added to the pool
        - It supports a .reset() method for in-place reinitialization
        - The method to add bytes to the pool is .append(), not .update().
    """

    digest_size = SHAd256.digest_size

    def __init__(self):
        self.reset()

    def append(self, data):
        self._h.update(data)
        self.length += len(data)

    def digest(self):
        return self._h.digest()

    def hexdigest(self):
        if sys.version_info[0] == 2:
            return b2a_hex(self.digest())
        else:
            return b2a_hex(self.digest()).decode()

    def reset(self):
        self._h = SHAd256.new()
        self.length = 0

def which_pools(r):
    """Return a list of pools indexes (in range(32)) that are to be included during reseed number r.

    According to _Practical Cryptography_, chapter 10.5.2 "Pools":

        "Pool P_i is included if 2**i is a divisor of r.  Thus P_0 is used
        every reseed, P_1 every other reseed, P_2 every fourth reseed, etc."
    """
    # This is a separate function so that it can be unit-tested.
    assert r >= 1
    retval = []
    mask = 0
    for i in range(32):
        # "Pool P_i is included if 2**i is a divisor of [reseed_count]"
        if (r & mask) == 0:
            retval.append(i)
        else:
            break   # optimization.  once this fails, it always fails
        mask = (mask << 1) | 1L
    return retval

class FortunaAccumulator(object):

    min_pool_size = 64      # TODO: explain why
    reseed_interval = 0.100   # 100 ms    TODO: explain why

    def __init__(self):
        self.reseed_count = 0
        self.generator = FortunaGenerator.AESGenerator()
        self.last_reseed = None

        # Initialize 32 FortunaPool instances.
        # NB: This is _not_ equivalent to [FortunaPool()]*32, which would give
        # us 32 references to the _same_ FortunaPool instance (and cause the
        # assertion below to fail).
        self.pools = [FortunaPool() for i in range(32)]     # 32 pools
        assert(self.pools[0] is not self.pools[1])

    def random_data(self, bytes):
        current_time = time.time()
        if (self.last_reseed is not None and self.last_reseed > current_time): # Avoid float comparison to None to make Py3k happy
            warnings.warn("Clock rewind detected. Resetting last_reseed.", ClockRewindWarning)
            self.last_reseed = None
        if (self.pools[0].length >= self.min_pool_size and
            (self.last_reseed is None or
             current_time > self.last_reseed + self.reseed_interval)):
            self._reseed(current_time)
        # The following should fail if we haven't seeded the pool yet.
        return self.generator.pseudo_random_data(bytes)

    def _reseed(self, current_time=None):
        if current_time is None:
            current_time = time.time()
        seed = []
        self.reseed_count += 1
        self.last_reseed = current_time
        for i in which_pools(self.reseed_count):
            seed.append(self.pools[i].digest())
            self.pools[i].reset()

        seed = b("").join(seed)
        self.generator.reseed(seed)

    def add_random_event(self, source_number, pool_number, data):
        assert 1 <= len(data) <= 32
        assert 0 <= source_number <= 255
        assert 0 <= pool_number <= 31
        self.pools[pool_number].append(bchr(source_number))
        self.pools[pool_number].append(bchr(len(data)))
        self.pools[pool_number].append(data)

# vim:set ts=4 sw=4 sts=4 expandtab:
