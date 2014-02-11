# -*- coding: utf-8 -*-
#
#  Random/__init__.py : PyCrypto random number generation
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
__all__ = ['new']

from Crypto.Random import OSRNG
from Crypto.Random import _UserFriendlyRNG

def new(*args, **kwargs):
    """Return a file-like object that outputs cryptographically random bytes."""
    return _UserFriendlyRNG.new(*args, **kwargs)

def atfork():
    """Call this whenever you call os.fork()"""
    _UserFriendlyRNG.reinit()

def get_random_bytes(n):
    """Return the specified number of cryptographically-strong random bytes."""
    return _UserFriendlyRNG.get_random_bytes(n)

# vim:set ts=4 sw=4 sts=4 expandtab:
