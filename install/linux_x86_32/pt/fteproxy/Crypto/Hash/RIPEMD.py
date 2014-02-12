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

"""RIPEMD-160 cryptographic hash algorithm.

RIPEMD-160_ produces the 160 bit digest of a message.

    >>> from Crypto.Hash import RIPEMD
    >>>
    >>> h = RIPEMD.new()
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

RIPEMD-160 stands for RACE Integrity Primitives Evaluation Message Digest
with a 160 bit digest. It was invented by Dobbertin, Bosselaers, and Preneel.

This algorithm is considered secure, although it has not been scrutinized as
extensively as SHA-1. Moreover, it provides an informal security level of just
80bits.

.. _RIPEMD-160: http://homes.esat.kuleuven.be/~bosselae/ripemd160.html
"""

_revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'RIPEMD160Hash' ]

from Crypto.Util.py3compat import *
from Crypto.Hash.hashalgo import HashAlgo

import Crypto.Hash._RIPEMD160 as _RIPEMD160
hashFactory = _RIPEMD160

class RIPEMD160Hash(HashAlgo):
    """Class that implements a RIPMD-160 hash
    
    :undocumented: block_size
    """

    #: ASN.1 Object identifier (OID)::
    #:
    #:  id-ripemd160 OBJECT IDENTIFIER ::= {
    #:      iso(1) identified-organization(3) teletrust(36)
    #:       algorithm(3) hashAlgorithm(2) ripemd160(1)
    #:  }
    #:
    #: This value uniquely identifies the RIPMD-160 algorithm.
    oid = b("\x06\x05\x2b\x24\x03\x02\x01")

    digest_size = 20
    block_size = 64

    def __init__(self, data=None):
        HashAlgo.__init__(self, hashFactory, data)

    def new(self, data=None):
        return RIPEMD160Hash(data)

def new(data=None):
    """Return a fresh instance of the hash object.

    :Parameters:
       data : byte string
        The very first chunk of the message to hash.
        It is equivalent to an early call to `RIPEMD160Hash.update()`.
        Optional.

    :Return: A `RIPEMD160Hash` object
    """
    return RIPEMD160Hash().new(data)

#: The size of the resulting hash in bytes.
digest_size = RIPEMD160Hash.digest_size

#: The internal block size of the hash algorithm in bytes.
block_size = RIPEMD160Hash.block_size

