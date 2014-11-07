# -*- coding: utf-8 -*-
#
#  Cipher/AES.py : AES
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
"""AES symmetric cipher

AES `(Advanced Encryption Standard)`__ is a symmetric block cipher standardized
by NIST_ . It has a fixed data block size of 16 bytes.
Its keys can be 128, 192, or 256 bits long.

AES is very fast and secure, and it is the de facto standard for symmetric
encryption.

As an example, encryption can be done as follows:

    >>> from Crypto.Cipher import AES
    >>> from Crypto import Random
    >>>
    >>> key = b'Sixteen byte key'
    >>> iv = Random.new().read(AES.block_size)
    >>> cipher = AES.new(key, AES.MODE_CFB, iv)
    >>> msg = iv + cipher.encrypt(b'Attack at dawn')

.. __: http://en.wikipedia.org/wiki/Advanced_Encryption_Standard
.. _NIST: http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf

:undocumented: __revision__, __package__
"""

__revision__ = "$Id$"

from Crypto.Cipher import blockalgo
from Crypto.Cipher import _AES

class AESCipher (blockalgo.BlockAlgo):
    """AES cipher object"""

    def __init__(self, key, *args, **kwargs):
        """Initialize an AES cipher object
        
        See also `new()` at the module level."""
        blockalgo.BlockAlgo.__init__(self, _AES, key, *args, **kwargs)

def new(key, *args, **kwargs):
    """Create a new AES cipher

    :Parameters:
      key : byte string
        The secret key to use in the symmetric cipher.
        It must be 16 (*AES-128*), 24 (*AES-192*), or 32 (*AES-256*) bytes long.
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

    :Return: an `AESCipher` object
    """
    return AESCipher(key, *args, **kwargs)

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
block_size = 16
#: Size of a key (in bytes)
key_size = ( 16, 24, 32 )

