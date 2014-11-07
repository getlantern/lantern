#
#  Random/OSRNG/posix.py : OS entropy source for POSIX systems
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
__all__ = ['DevURandomRNG']

import errno
import os
import stat

from rng_base import BaseRNG
from Crypto.Util.py3compat import b

class DevURandomRNG(BaseRNG):

    def __init__(self, devname=None):
        if devname is None:
            self.name = "/dev/urandom"
        else:
            self.name = devname

        # Test that /dev/urandom is a character special device
        f = open(self.name, "rb", 0)
        fmode = os.fstat(f.fileno())[stat.ST_MODE]
        if not stat.S_ISCHR(fmode):
            f.close()
            raise TypeError("%r is not a character special device" % (self.name,))

        self.__file = f

        BaseRNG.__init__(self)

    def _close(self):
        self.__file.close()

    def _read(self, N):
        # Starting with Python 3 open with buffering=0 returns a FileIO object.
        # FileIO.read behaves like read(2) and not like fread(3) and thus we
        # have to handle the case that read returns less data as requested here
        # more carefully.
        data = b("")
        while len(data) < N:
            try:
                d = self.__file.read(N - len(data))
            except IOError, e:
                # read(2) has been interrupted by a signal; redo the read
                if e.errno == errno.EINTR:
                    continue
                raise

            if d is None:
                # __file is in non-blocking mode and no data is available
                return data
            if len(d) == 0:
                # __file is in blocking mode and arrived at EOF
                return data

            data += d
        return data

def new(*args, **kwargs):
    return DevURandomRNG(*args, **kwargs)


# vim:set ts=4 sw=4 sts=4 expandtab:
