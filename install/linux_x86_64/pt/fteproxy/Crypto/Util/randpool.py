#
#  randpool.py : Cryptographically strong random number generation
#
# Part of the Python Cryptography Toolkit
#
# Written by Andrew M. Kuchling, Mark Moraes, and others
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
#

__revision__ = "$Id$"

from Crypto.pct_warnings import RandomPool_DeprecationWarning
import Crypto.Random
import warnings

class RandomPool:
    """Deprecated.  Use Random.new() instead.

    See http://www.pycrypto.org/randpool-broken
    """
    def __init__(self, numbytes = 160, cipher=None, hash=None, file=None):
        warnings.warn("This application uses RandomPool, which is BROKEN in older releases.  See http://www.pycrypto.org/randpool-broken",
            RandomPool_DeprecationWarning)
        self.__rng = Crypto.Random.new()
        self.bytes = numbytes
        self.bits = self.bytes * 8
        self.entropy = self.bits

    def get_bytes(self, N):
        return self.__rng.read(N)

    def _updateEntropyEstimate(self, nbits):
        self.entropy += nbits
        if self.entropy < 0:
            self.entropy = 0
        elif self.entropy > self.bits:
            self.entropy = self.bits

    def _randomize(self, N=0, devname="/dev/urandom"):
        """Dummy _randomize() function"""
        self.__rng.flush()

    def randomize(self, N=0):
        """Dummy randomize() function"""
        self.__rng.flush()

    def stir(self, s=''):
        """Dummy stir() function"""
        self.__rng.flush()

    def stir_n(self, N=3):
        """Dummy stir_n() function"""
        self.__rng.flush()

    def add_event(self, s=''):
        """Dummy add_event() function"""
        self.__rng.flush()

    def getBytes(self, N):
        """Dummy getBytes() function"""
        return self.get_bytes(N)

    def addEvent(self, event, s=""):
        """Dummy addEvent() function"""
        return self.add_event()
