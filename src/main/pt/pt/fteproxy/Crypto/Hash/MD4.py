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

"""MD4 cryptographic hash algorithm.

MD4 is specified in RFC1320_ and produces the 128 bit digest of a message.

    >>> from Crypto.Hash import MD4
    >>>
    >>> h = MD4.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

MD4 stand for Message Digest version 4, and it was invented by Rivest in 1990.

This algorithm is insecure. Do not use it for new designs.

.. _RFC1320: http://tools.ietf.org/html/rfc1320
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'MD4Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

import Crypto.Hash._MD4 as _MD4
hashFactory = _MD4

class MD4Hash(HashAlgo):
    """Class that implements an MD4 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-md2 OBJECT IDENTIFIER ::= {
    #:      iso(1) member-body(2) us(840) rsadsi(113549)
    #:       digestAlgorithm(2) 4
    #:  }
    #:
    #: This value uniquely identifies the MD4 algorithm.
    oid = b('\x06\x08\x2a\x86\x48\x86\xf7\x0d\x02\x04')

    digest_size = 16
    block_size = 64

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return MD4Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `MD4Hash.update()`.
        Optional.

    :Return: A `MD4Hash` object
    """
    return MD4Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = MD4Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = MD4Hash.block_size

