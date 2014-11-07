# -*- coding: utf-8 -*-
#
#  Cipher/ARC2.py : ARC2.py
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
"""RC2 symmetric cipher

RC2_ (Rivest's Cipher version 2)  is a symmetric block cipher designed
by Ron Rivest in 1987. The cipher started as a proprietary design,
that was reverse engineered and anonymously posted on Usenet in 1996.
For this reason, the algorithm was first called *Alleged* RC2 (ARC2),
since the company that owned RC2 (RSA Data Inc.) did not confirm whether
the details leaked into public domain were really correct.

The company eventually published its full specification in RFC2268_.

RC2 has a fixed data block size of 8 bytes. Length of its keys can vary from
8 to 128 bits. One particular property of RC2 is that the actual
cryptographic strength of the key (*effective key length*) can be reduced 
via a parameter.

Even though RC2 is not cryptographically broken, it has not been analyzed as
thoroughly as AES, which is also faster than RC2.

New designs should not use RC2.

As an example, encryption can be done as follows:

    >>> from Crypto.Cipher import ARC2
    >>> from Crypto import Random
    >>>
    >>> key = b'Sixteen byte key'
    >>> iv = Random.new().read(ARC2.block_size)
    >>> cipher = ARC2.new(key, ARC2.MODE_CFB, iv)
    >>> msg = iv + cipher.encrypt(b'Attack at dawn')

.. _RC2: http://en.wikipedia.org/wiki/RC2
.. _RFC2268: http://tools.ietf.org/html/rfc2268

:undocumented: __revision__, __package__
"""

__revision__ = "$Id$"

from Crypto.Cipher import blockalgo
from Crypto.Cipher import _ARC2

class RC2Cipher (blockalgo.BlockAlgo):
    """RC2 cipher object"""

    def __init__(self, key, *args, **kwargs):
        """Initialize an ARC2 cipher object
        
        See also `new()` at the module level."""
        blockalgo.BlockAlgo.__init__(self, _ARC2, key, *args, **kwargs)

def new(key, *args, **kwargs):
    """Create a new RC2 cipher

    :Parameters:
      key : byte string
        The secret key to use in the symmetric cipher.
        Its length can vary from 1 to 128 bytes.
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
       
        For all other modes, it must be `block_size` bytes longs. It is optional and
        when not present it will be given a default value of all zeroes.
      counter : callable
        (*Only* `MODE_CTR`). A stateful function that returns the next
        *counter block*, which is a byte string of `block_size` bytes.
        For better performance, use `Crypto.Util.Counter`.
      segment_size : integer
        (*Only* `MODE_CFB`).The number of bits the plaintext and ciphertext
        are segmented in.
        It must be a multiple of 8. If 0 or not specified, it will be assumed to be 8.
      effective_keylen : integer
        Maximum cryptographic strength of the key, in bits.
        It can vary from 0 to 1024. The default value is 1024.

    :Return: an `RC2Cipher` object
    """
    return RC2Cipher(key, *args, **kwargs)

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
key_size = xrange(1,16+1)

