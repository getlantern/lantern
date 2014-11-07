#
#   pubkey.py : Internal functions for public key operations
#
#  Part of the Python Cryptography Toolkit
#
#  Written by Andrew Kuchling, Paul Swartz, and others
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
#

__revision__ = "$Id$"

import types, warnings
from Crypto.Util.number import *

# Basic public key class
class pubkey:
    """An abstract class for a public key object.

    :undocumented: __getstate__, __setstate__, __eq__, __ne__, validate
    """
    def __init__(self):
        pass

    def __getstate__(self):
        """To keep key objects platform-independent, the key data is
        converted to standard Python long integers before being
        written out.  It will then be reconverted as necessary on
        restoration."""
        d=self.__dict__
        for key in self.keydata:
            if d.has_key(key): d[key]=long(d[key])
        return d

    def __setstate__(self, d):
        """On unpickling a key object, the key data is converted to the big
number representation being used, whether that is Python long
integers, MPZ objects, or whatever."""
        for key in self.keydata:
            if d.has_key(key): self.__dict__[key]=bignum(d[key])

    def encrypt(self, plaintext, K):
        """Encrypt a piece of data.

        :Parameter plaintext: The piece of data to encrypt.
        :Type plaintext: byte string or long

        :Parameter K: A random parameter required by some algorithms
        :Type K: byte string or long

        :Return: A tuple with two items. Each item is of the same type as the
         plaintext (string or long).
        """
        wasString=0
        if isinstance(plaintext, types.StringType):
            plaintext=bytes_to_long(plaintext) ; wasString=1
        if isinstance(K, types.StringType):
            K=bytes_to_long(K)
        ciphertext=self._encrypt(plaintext, K)
        if wasString: return tuple(map(long_to_bytes, ciphertext))
        else: return ciphertext

    def decrypt(self, ciphertext):
        """Decrypt a piece of data. 

        :Parameter ciphertext: The piece of data to decrypt.
        :Type ciphertext: byte string, long or a 2-item tuple as returned by `encrypt`

        :Return: A byte string if ciphertext was a byte string or a tuple
         of byte strings. A long otherwise.
        """
        wasString=0
        if not isinstance(ciphertext, types.TupleType):
            ciphertext=(ciphertext,)
        if isinstance(ciphertext[0], types.StringType):
            ciphertext=tuple(map(bytes_to_long, ciphertext)) ; wasString=1
        plaintext=self._decrypt(ciphertext)
        if wasString: return long_to_bytes(plaintext)
        else: return plaintext

    def sign(self, M, K):
        """Sign a piece of data.

        :Parameter M: The piece of data to encrypt.
        :Type M: byte string or long

        :Parameter K: A random parameter required by some algorithms
        :Type K: byte string or long

        :Return: A tuple with two items.
        """
        if (not self.has_private()):
            raise TypeError('Private key not available in this object')
        if isinstance(M, types.StringType): M=bytes_to_long(M)
        if isinstance(K, types.StringType): K=bytes_to_long(K)
        return self._sign(M, K)

    def verify (self, M, signature):
        """Verify the validity of a signature.

        :Parameter M: The expected message.
        :Type M: byte string or long

        :Parameter signature: The signature to verify.
        :Type signature: tuple with two items, as return by `sign`

        :Return: True if the signature is correct, False otherwise.
        """
        if isinstance(M, types.StringType): M=bytes_to_long(M)
        return self._verify(M, signature)

    # alias to compensate for the old validate() name
    def validate (self, M, signature):
        warnings.warn("validate() method name is obsolete; use verify()",
                      DeprecationWarning)

    def blind(self, M, B):
        """Blind a message to prevent certain side-channel attacks.
       
        :Parameter M: The message to blind.
        :Type M: byte string or long

        :Parameter B: Blinding factor.
        :Type B: byte string or long

        :Return: A byte string if M was so. A long otherwise.
        """
        wasString=0
        if isinstance(M, types.StringType):
            M=bytes_to_long(M) ; wasString=1
        if isinstance(B, types.StringType): B=bytes_to_long(B)
        blindedmessage=self._blind(M, B)
        if wasString: return long_to_bytes(blindedmessage)
        else: return blindedmessage

    def unblind(self, M, B):
        """Unblind a message after cryptographic processing.
        
        :Parameter M: The encoded message to unblind.
        :Type M: byte string or long

        :Parameter B: Blinding factor.
        :Type B: byte string or long
        """
        wasString=0
        if isinstance(M, types.StringType):
            M=bytes_to_long(M) ; wasString=1
        if isinstance(B, types.StringType): B=bytes_to_long(B)
        unblindedmessage=self._unblind(M, B)
        if wasString: return long_to_bytes(unblindedmessage)
        else: return unblindedmessage


    # The following methods will usually be left alone, except for
    # signature-only algorithms.  They both return Boolean values
    # recording whether this key's algorithm can sign and encrypt.
    def can_sign (self):
        """Tell if the algorithm can deal with cryptographic signatures.

        This property concerns the *algorithm*, not the key itself.
        It may happen that this particular key object hasn't got
        the private information required to generate a signature.

        :Return: boolean
        """
        return 1

    def can_encrypt (self):
        """Tell if the algorithm can deal with data encryption.
       
        This property concerns the *algorithm*, not the key itself.
        It may happen that this particular key object hasn't got
        the private information required to decrypt data.

        :Return: boolean
        """
        return 1

    def can_blind (self):
        """Tell if the algorithm can deal with data blinding.
       
        This property concerns the *algorithm*, not the key itself.
        It may happen that this particular key object hasn't got
        the private information required carry out blinding.

        :Return: boolean
        """
        return 0

    # The following methods will certainly be overridden by
    # subclasses.

    def size (self):
        """Tell the maximum number of bits that can be handled by this key.

        :Return: int
        """
        return 0

    def has_private (self):
        """Tell if the key object contains private components.

        :Return: bool
        """
        return 0

    def publickey (self):
        """Construct a new key carrying only the public information.

        :Return: A new `pubkey` object.
        """
        return self

    def __eq__ (self, other):
        """__eq__(other): 0, 1
        Compare us to other for equality.
        """
        return self.__getstate__() == other.__getstate__()

    def __ne__ (self, other):
        """__ne__(other): 0, 1
        Compare us to other for inequality.
        """
        return not self.__eq__(other)
