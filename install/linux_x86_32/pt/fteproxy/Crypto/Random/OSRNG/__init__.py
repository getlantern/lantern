#
#  Random/OSRNG/__init__.py : Platform-independent OS RNG API
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

"""Provides a platform-independent interface to the random number generators
supplied by various operating systems."""

__revision__ = "$Id$"

import os

if os.name == 'posix':
    from Crypto.Random.OSRNG.posix import new
elif os.name == 'nt':
    from Crypto.Random.OSRNG.nt import new
elif hasattr(os, 'urandom'):
    from Crypto.Random.OSRNG.fallback import new
else:
    raise ImportError("Not implemented")

# vim:set ts=4 sw=4 sts=4 expandtab:
