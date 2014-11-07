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

"""MD2 cryptographic hash algorithm.

MD2 is specified in RFC1319_ and it produces the 128 bit digest of a message.

    >>> from Crypto.Hash import MD2
    >>>
    >>> h = MD2.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

MD2 stand for Message Digest version 2, and it was invented by Rivest in 1989.

This algorithm is both slow and insecure. Do not use it for new designs.

.. _RFC1319: http://tools.ietf.org/html/rfc1319
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'MD2Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

import Crypto.Hash._MD2 as _MD2
hashFactory = _MD2

class MD2Hash(HashAlgo):
    """Class that implements an MD2 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-md2 OBJECT IDENTIFIER ::= {
    #:      iso(1) member-body(2) us(840) rsadsi(113549)
    #:       digestAlgorithm(2) 2
    #:  }
    #:
    #: This value uniquely identifies the MD2 algorithm.
    oid = b('\x06\x08\x2a\x86\x48\x86\xf7\x0d\x02\x02')

    digest_size = 16
    block_size = 16

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return MD2Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `MD2Hash.update()`.
        Optional.

    :Return: An `MD2Hash` object
    """
    return MD2Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = MD2Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = MD2Hash.block_size

