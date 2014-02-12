# -*- coding: utf-8 -*-
#
#  Cipher/ARC4.py : ARC4
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
"""ARC4 symmetric cipher

ARC4_ (Alleged RC4) is an implementation of RC4 (Rivest's Cipher version 4),
a symmetric stream cipher designed by Ron Rivest in 1987.

The cipher started as a proprietary design, that was reverse engineered and
anonymously posted on Usenet in 1994. The company that owns RC4 (RSA Data
Inc.) never confirmed the correctness of the leaked algorithm.

Unlike RC2, the company has never published the full specification of RC4,
of whom it still holds the trademark.

ARC4 keys can vary in length from 40 to 2048 bits.

One problem of ARC4 is that it does not take a nonce or an IV. If it is required
to encrypt multiple messages with the same long-term key, a distinct
independent nonce must be created for each message, and a short-term key must
be derived from the combination of the long-term key and the nonce.
Due to the weak key scheduling algorithm of RC2, the combination must be carried
out with a complex function (e.g. a cryptographic hash) and not by simply
concatenating key and nonce.

New designs should not use ARC4. A good alternative is AES
(`Crypto.Cipher.AES`) in any of the modes that turn it into a stream cipher (OFB, CFB, or CTR).

As an example, encryption can be done as follows:

    >>> from Crypto.Cipher import ARC4
    >>> from Crypto.Hash import SHA
    >>> from Crypto import Random
    >>>
    >>> key = b'Very long and confidential key'
    >>> nonce = Random.new().read(16)
    >>> tempkey = SHA.new(key+nonce).digest()
    >>> cipher = ARC4.new(tempkey)
    >>> msg = nonce + cipher.encrypt(b'Open the pod bay doors, HAL')

.. _ARC4: http://en.wikipedia.org/wiki/RC4

:undocumented: __revision__, __package__
"""

__revision__ = "$Id$"

from Crypto.Cipher import _ARC4

class ARC4Cipher:
    """ARC4 cipher object"""


    def __init__(self, key, *args, **kwargs):
        """Initialize an ARC4 cipher object
        
        See also `new()` at the module level."""

        self._cipher = _ARC4.new(key, *args, **kwargs)
        self.block_size = self._cipher.block_size
        self.key_size = self._cipher.key_size

    def encrypt(self, plaintext):
        """Encrypt a piece of data.

        :Parameters:
          plaintext : byte string
            The piece of data to encrypt. It can be of any size.
        :Return: the encrypted data (byte string, as long as the
          plaintext).
        """
        return self._cipher.encrypt(plaintext)

    def decrypt(self, ciphertext):
        """Decrypt a piece of data.

        :Parameters:
          ciphertext : byte string
            The piece of data to decrypt. It can be of any size.
        :Return: the decrypted data (byte string, as long as the
          ciphertext).
        """
        return self._cipher.decrypt(ciphertext)

def new(key, *args, **kwargs):
    """Create a new ARC4 cipher

    :Parameters:
      key : byte string
        The secret key to use in the symmetric cipher.
        It can have any length, with a minimum of 40 bytes.
        Its cryptograpic strength is always capped to 2048 bits (256 bytes).

    :Return: an `ARC4Cipher` object
    """
    return ARC4Cipher(key, *args, **kwargs)

#: Size of a data block (in bytes)
block_size = 1
#: Size of a key (in bytes)
key_size = xrange(1,256+1)

