# -*- coding: utf-8 -*-
#
#  Cipher/CAST.py : CAST
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
"""CAST-128 symmetric cipher

CAST-128_ (or CAST5) is a symmetric block cipher specified in RFC2144_.

It has a fixed data block size of 8 bytes. Its key can vary in length
from 40 to 128 bits.

CAST is deemed to be cryptographically secure, but its usage is not widespread.
Keys of sufficient length should be used to prevent brute force attacks
(128 bits are recommended).

As an example, encryption can be done as follows:

    >>> from Crypto.Cipher import CAST
    >>> from Crypto import Random
    >>>
    >>> key = b'Sixteen byte key'
    >>> iv = Random.new().read(CAST.block_size)
    >>> cipher = CAST.new(key, CAST.MODE_OPENPGP, iv)
    >>> plaintext = b'sona si latine loqueris '
    >>> msg = cipher.encrypt(plaintext)
    >>>
    ...
    >>> eiv = msg[:CAST.block_size+2]
    >>> ciphertext = msg[CAST.block_size+2:]
    >>> cipher = CAST.new(key, CAST.MODE_OPENPGP, eiv)
    >>> print cipher.decrypt(ciphertext)

.. _CAST-128: http://en.wikipedia.org/wiki/CAST-128
.. _RFC2144: http://tools.ietf.org/html/rfc2144

:undocumented: __revision__, __package__
"""

__revision__ = "$Id$"

from Crypto.Cipher import blockalgo
from Crypto.Cipher import _CAST

class CAST128Cipher(blockalgo.BlockAlgo):
    """CAST-128 cipher object"""

    def __init__(self, key, *args, **kwargs):
        """Initialize a CAST-128 cipher object
        
        See also `new()` at the module level."""
        blockalgo.BlockAlgo.__init__(self, _CAST, key, *args, **kwargs)

def new(key, *args, **kwargs):
    """Create a new CAST-128 cipher

    :Parameters:
      key : byte string
        The secret key to use in the symmetric cipher.
        Its length may vary from 5 to 16 bytes.
    :Keywords:
      mode : a *MODE_** constant
        The chaining mode to use for encryption or decryption.
        Default is `MODE_ECB`.
      IV : byte string
        The initialization vector to use for encryption or decryption.
        
        It is ignored for `MODE_ECB` and `MODE_CTR`.

        For `MODE_OPENPGP`, IV must be `block_size` bytes long for encryption
        and `block_size` +2 bytes for decryption (in the latter case, it is
        actually the *encrypted* IV which was prefixed to the ciphertext).
        It is mandatory.
       
        For all other modes, it must be `block_size` bytes longs.
      counter : callable
        (*Only* `MODE_CTR`). A stateful function that returns the next
        *counter block*, which is a byte string of `block_size` bytes.
        For better performance, use `Crypto.Util.Counter`.
      segment_size : integer
        (*Only* `MODE_CFB`).The number of bits the plaintext and ciphertext
        are segmented in.
        It must be a multiple of 8. If 0 or not specified, it will be assumed to be 8.

    :Return: an `CAST128Cipher` object
    """
    return CAST128Cipher(key, *args, **kwargs)

#: Electronic Code Book (ECB). See `blockalgo.MODE_ECB`.
MODE_ECB = 1
#: Cipher-Block Chaining (CBC). See `blockalgo.MODE_CBC`.
MODE_CBC = 2
#: Cipher FeedBack (CFB). See `blockalgo.MODE_CFB`.
MODE_CFB = 3
#: This mode should not be used.
MODE_PGP = 4
#: Output FeedBack (OFB). See `blockalgo.MODE_OFB`.
MODE_OFB = 5
#: CounTer Mode (CTR). See `blockalgo.MODE_CTR`.
MODE_CTR = 6
#: OpenPGP Mode. See `blockalgo.MODE_OPENPGP`.
MODE_OPENPGP = 7
#: Size of a data block (in bytes)
block_size = 8
#: Size of a key (in bytes)
key_size = xrange(5,16+1)
