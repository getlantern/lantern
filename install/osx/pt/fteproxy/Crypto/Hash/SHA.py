# -*- coding: utf-8 -*-
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

"""SHA-1 cryptographic hash algorithm.

SHA-1_ produces the 160 bit digest of a message.

    >>> from Crypto.Hash import SHA
    >>>
    >>> h = SHA.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

*SHA* stands for Secure Hash Algorithm.

This algorithm is not considered secure. Do not use it for new designs.

.. _SHA-1: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'SHA1Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

try:
    # The sha module is deprecated in Python 2.6, so use hashlib when possible.
    import hashlib
    hashFactory = hashlib.sha1

except ImportError:
    import sha
    hashFactory = sha

class SHA1Hash(HashAlgo):
    """Class that implements a SHA-1 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-sha1    OBJECT IDENTIFIER ::= {
    #:      iso(1) identified-organization(3) oiw(14) secsig(3)
    #:       algorithms(2) 26
    #:  }
    #:
    #: This value uniquely identifies the SHA-1 algorithm.
    oid = b('\x06\x05\x2b\x0e\x03\x02\x1a')

    digest_size = 20
    block_size = 64

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return SHA1Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `SHA1Hash.update()`.
        Optional.

    :Return: A `SHA1Hash` object
    """
    return SHA1Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = SHA1Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = SHA1Hash.block_size


