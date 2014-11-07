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

"""SHA-384 cryptographic hash algorithm.

SHA-384 belongs to the SHA-2_ family of cryptographic hashes.
It produces the 384 bit digest of a message.

    >>> from Crypto.Hash import SHA384
    >>>
    >>> h = SHA384.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

*SHA* stands for Secure Hash Algorithm.

.. _SHA-2: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'SHA384Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

try:
    import hashlib
    hashFactory = hashlib.sha384

except ImportError:
    from Crypto.Hash import _SHA384
    hashFactory = _SHA384

class SHA384Hash(HashAlgo):
    """Class that implements a SHA-384 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-sha384    OBJECT IDENTIFIER ::= {
    #:      joint-iso-itu-t(2) country(16) us(840) organization(1) gov(101) csor(3)
    #:	     nistalgorithm(4) hashalgs(2) 2
    #:  }
    #:
    #: This value uniquely identifies the SHA-384 algorithm.
    oid = b('\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x02')

    digest_size = 48
    block_size = 128

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return SHA384Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `SHA384Hash.update()`.
        Optional.

    :Return: A `SHA384Hash` object
    """
    return SHA384Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = SHA384Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = SHA384Hash.block_size


