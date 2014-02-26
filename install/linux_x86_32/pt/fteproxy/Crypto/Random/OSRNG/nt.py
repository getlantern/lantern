#
#  Random/OSRNG/nt.py : OS entropy source for MS Windows
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
__all__ = ['WindowsRNG']

import winrandom
from rng_base import BaseRNG

class WindowsRNG(BaseRNG):

    name = "<CryptGenRandom>"

    def __init__(self):
        self.__winrand = winrandom.new()
        BaseRNG.__init__(self)

    def flush(self):
        """Work around weakness in Windows RNG.

        The CryptGenRandom mechanism in some versions of Windows allows an
        attacker to learn 128 KiB of past and future output.  As a workaround,
        this function reads 128 KiB of 'random' data from Windows and discards
        it.

        For more information about the weaknesses in CryptGenRandom, see
        _Cryptanalysis of the Random Number Generator of the Windows Operating
        System_, by Leo Dorrendorf and Zvi Gutterman and Benny Pinkas
        http://eprint.iacr.org/2007/419
        """
        if self.closed:
            raise ValueError("I/O operation on closed file")
        data = self.__winrand.get_bytes(128*1024)
        assert (len(data) == 128*1024)
        BaseRNG.flush(self)

    def _close(self):
        self.__winrand = None

    def _read(self, N):
        # Unfortunately, research shows that CryptGenRandom doesn't provide
        # forward secrecy and fails the next-bit test unless we apply a
        # workaround, which we do here.  See http://eprint.iacr.org/2007/419
        # for information on the vulnerability.
        self.flush()
        data = self.__winrand.get_bytes(N)
        self.flush()
        return data

def new(*args, **kwargs):
    return WindowsRNG(*args, **kwargs)

# vim:set ts=4 sw=4 sts=4 expandtab:
