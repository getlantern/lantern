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

"""SHA-512 cryptographic hash algorithm.

SHA-512 belongs to the SHA-2_ family of cryptographic hashes.
It produces the 512 bit digest of a message.

    >>> from Crypto.Hash import SHA512
    >>>
    >>> h = SHA512.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

*SHA* stands for Secure Hash Algorithm.

.. _SHA-2: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'SHA512Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

try:
    import hashlib
    hashFactory = hashlib.sha512

except ImportError:
    from Crypto.Hash import _SHA512
    hashFactory = _SHA512

class SHA512Hash(HashAlgo):
    """Class that implements a SHA-512 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-sha512    OBJECT IDENTIFIER ::= {
    #:	    joint-iso-itu-t(2)
    #:	    country(16) us(840) organization(1) gov(101) csor(3) nistalgorithm(4) hashalgs(2) 3
    #:  }
    #:
    #: This value uniquely identifies the SHA-512 algorithm.
    oid = b('\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x03')

    digest_size = 64
    block_size = 128

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return SHA512Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `SHA512Hash.update()`.
        Optional.

    :Return: A `SHA512Hash` object
    """
    return SHA512Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = SHA512Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = SHA512Hash.block_size

