# -*- coding: utf-8 -*-
#
#  Cipher/blockalgo.py 
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
"""Module with definitions common to all block ciphers."""

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *
from Crypto.Util.py3compat import *

#: *Electronic Code Book (ECB)*.
#: This is the simplest encryption mode. Each of the plaintext blocks
#: is directly encrypted into a ciphertext block, independently of
#: any other block. This mode exposes frequency of symbols
#: in your plaintext. Other modes (e.g. *CBC*) should be used instead.
#:
#: See `NIST SP800-38A`_ , Section 6.1 .
#:
#: .. _`NIST SP800-38A` : http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
MODE_ECB = 1

#: *Cipher-Block Chaining (CBC)*. Each of the ciphertext blocks depends
#: on the current and all previous plaintext blocks. An Initialization Vector
#: (*IV*) is required.
#:
#: The *IV* is a data block to be transmitted to the receiver.
#: The *IV* can be made public, but it must be authenticated by the receiver and
#: it should be picked randomly.
#:
#: See `NIST SP800-38A`_ , Section 6.2 .
#:
#: .. _`NIST SP800-38A` : http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
MODE_CBC = 2

#: *Cipher FeedBack (CFB)*. This mode is similar to CBC, but it transforms
#: the underlying block cipher into a stream cipher. Plaintext and ciphertext
#: are processed in *segments* of **s** bits. The mode is therefore sometimes
#: labelled **s**-bit CFB. An Initialization Vector (*IV*) is required.
#:
#: When encrypting, each ciphertext segment contributes to the encryption of
#: the next plaintext segment.
#:
#: This *IV* is a data block to be transmitted to the receiver.
#: The *IV* can be made public, but it should be picked randomly.
#: Reusing the same *IV* for encryptions done with the same key lead to
#: catastrophic cryptographic failures.
#:
#: See `NIST SP800-38A`_ , Section 6.3 .
#:
#: .. _`NIST SP800-38A` : http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
MODE_CFB = 3

#: This mode should not be used.
MODE_PGP = 4

#: *Output FeedBack (OFB)*. This mode is very similar to CBC, but it
#: transforms the underlying block cipher into a stream cipher.
#: The keystream is the iterated block encryption of an Initialization Vector (*IV*).
#:
#: The *IV* is a data block to be transmitted to the receiver.
#: The *IV* can be made public, but it should be picked randomly.
#:
#: Reusing the same *IV* for encryptions done with the same key lead to
#: catastrophic cryptograhic failures.
#:
#: See `NIST SP800-38A`_ , Section 6.4 .
#:
#: .. _`NIST SP800-38A` : http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
MODE_OFB = 5

#: *CounTeR (CTR)*. This mode is very similar to ECB, in that
#: encryption of one block is done independently of all other blocks.
#: Unlike ECB, the block *position* contributes to the encryption and no
#: information leaks about symbol frequency.
#:
#: Each message block is associated to a *counter* which must be unique
#: across all messages that get encrypted with the same key (not just within
#: the same message). The counter is as big as the block size.
#:
#: Counters can be generated in several ways. The most straightword one is
#: to choose an *initial counter block* (which can be made public, similarly
#: to the *IV* for the other modes) and increment its lowest **m** bits by
#: one (modulo *2^m*) for each block. In most cases, **m** is chosen to be half
#: the block size.
#: 
#: Reusing the same *initial counter block* for encryptions done with the same
#: key lead to catastrophic cryptograhic failures.
#:
#: See `NIST SP800-38A`_ , Section 6.5 (for the mode) and Appendix B (for how
#: to manage the *initial counter block*).
#:
#: .. _`NIST SP800-38A` : http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf
MODE_CTR = 6

#: OpenPGP. This mode is a variant of CFB, and it is only used in PGP and OpenPGP_ applications.
#: An Initialization Vector (*IV*) is required.
#: 
#: Unlike CFB, the IV is not transmitted to the receiver. Instead, the *encrypted* IV is.
#: The IV is a random data block. Two of its bytes are duplicated to act as a checksum
#: for the correctness of the key. The encrypted IV is therefore 2 bytes longer than
#: the clean IV.
#:
#: .. _OpenPGP: http://tools.ietf.org/html/rfc4880
MODE_OPENPGP = 7

def _getParameter(name, index, args, kwargs, default=None):
    """Find a parameter in tuple and dictionary arguments a function receives"""
    param = kwargs.get(name)
    if len(args)>index:
        if param:
            raise ValueError("Parameter '%s' is specified twice" % name)
        param = args[index]
    return param or default
    
class BlockAlgo:
    """Class modelling an abstract block cipher."""

    def __init__(self, factory, key, *args, **kwargs):
        self.mode = _getParameter('mode', 0, args, kwargs, default=MODE_ECB)
        self.block_size = factory.block_size
        
        if self.mode != MODE_OPENPGP:
            self._cipher = factory.new(key, *args, **kwargs)
            self.IV = self._cipher.IV
        else:
            # OPENPGP mode. For details, see 13.9 in RCC4880.
            #
            # A few members are specifically created for this mode:
            #  - _encrypted_iv, set in this constructor
            #  - _done_first_block, set to True after the first encryption
            #  - _done_last_block, set to True after a partial block is processed
            
            self._done_first_block = False
            self._done_last_block = False
            self.IV = _getParameter('iv', 1, args, kwargs)
            if not self.IV:
                raise ValueError("MODE_OPENPGP requires an IV")
            
            # Instantiate a temporary cipher to process the IV
            IV_cipher = factory.new(key, MODE_CFB,
                    b('\x00')*self.block_size,      # IV for CFB
                    segment_size=self.block_size*8)
           
            # The cipher will be used for...
            if len(self.IV) == self.block_size:
                # ... encryption
                self._encrypted_IV = IV_cipher.encrypt(
                    self.IV + self.IV[-2:] +        # Plaintext
                    b('\x00')*(self.block_size-2)   # Padding
                    )[:self.block_size+2]
            elif len(self.IV) == self.block_size+2:
                # ... decryption
                self._encrypted_IV = self.IV
                self.IV = IV_cipher.decrypt(self.IV +   # Ciphertext
                    b('\x00')*(self.block_size-2)       # Padding
                    )[:self.block_size+2]
                if self.IV[-2:] != self.IV[-4:-2]:
                    raise ValueError("Failed integrity check for OPENPGP IV")
                self.IV = self.IV[:-2]
            else:
                raise ValueError("Length of IV must be %d or %d bytes for MODE_OPENPGP"
                    % (self.block_size, self.block_size+2))

            # Instantiate the cipher for the real PGP data
            self._cipher = factory.new(key, MODE_CFB,
                self._encrypted_IV[-self.block_size:],
                segment_size=self.block_size*8)

    def encrypt(self, plaintext):
        """Encrypt data with the key and the parameters set at initialization.
        
        The cipher object is stateful; encryption of a long block
        of data can be broken up in two or more calls to `encrypt()`.
        That is, the statement:
            
            >>> c.encrypt(a) + c.encrypt(b)

        is always equivalent to:

             >>> c.encrypt(a+b)

        That also means that you cannot reuse an object for encrypting
        or decrypting other data with the same key.

        This function does not perform any padding.
       
         - For `MODE_ECB`, `MODE_CBC`, and `MODE_OFB`, *plaintext* length
           (in bytes) must be a multiple of *block_size*.

         - For `MODE_CFB`, *plaintext* length (in bytes) must be a multiple
           of *segment_size*/8.

         - For `MODE_CTR`, *plaintext* can be of any length.

         - For `MODE_OPENPGP`, *plaintext* must be a multiple of *block_size*,
           unless it is the last chunk of the message.

        :Parameters:
          plaintext : byte string
            The piece of data to encrypt.
        :Return:
            the encrypted data, as a byte string. It is as long as
            *plaintext* with one exception: when encrypting the first message
            chunk with `MODE_OPENPGP`, the encypted IV is prepended to the
            returned ciphertext.
        """

        if self.mode == MODE_OPENPGP:
            padding_length = (self.block_size - len(plaintext) % self.block_size) % self.block_size
            if padding_length>0:
                # CFB mode requires ciphertext to have length multiple of block size,
                # but PGP mode allows the last block to be shorter
                if self._done_last_block:
                    raise ValueError("Only the last chunk is allowed to have length not multiple of %d bytes",
                        self.block_size)
                self._done_last_block = True
                padded = plaintext + b('\x00')*padding_length
                res = self._cipher.encrypt(padded)[:len(plaintext)]
            else:
                res = self._cipher.encrypt(plaintext)
            if not self._done_first_block:
                res = self._encrypted_IV + res
                self._done_first_block = True
            return res

        return self._cipher.encrypt(plaintext)

    def decrypt(self, ciphertext):
        """Decrypt data with the key and the parameters set at initialization.
        
        The cipher object is stateful; decryption of a long block
        of data can be broken up in two or more calls to `decrypt()`.
        That is, the statement:
            
            >>> c.decrypt(a) + c.decrypt(b)

        is always equivalent to:

             >>> c.decrypt(a+b)

        That also means that you cannot reuse an object for encrypting
        or decrypting other data with the same key.

        This function does not perform any padding.
       
         - For `MODE_ECB`, `MODE_CBC`, and `MODE_OFB`, *ciphertext* length
           (in bytes) must be a multiple of *block_size*.

         - For `MODE_CFB`, *ciphertext* length (in bytes) must be a multiple
           of *segment_size*/8.

         - For `MODE_CTR`, *ciphertext* can be of any length.

         - For `MODE_OPENPGP`, *plaintext* must be a multiple of *block_size*,
           unless it is the last chunk of the message.

        :Parameters:
          ciphertext : byte string
            The piece of data to decrypt.
        :Return: the decrypted data (byte string, as long as *ciphertext*).
        """
        if self.mode == MODE_OPENPGP:
            padding_length = (self.block_size - len(ciphertext) % self.block_size) % self.block_size
            if padding_length>0:
                # CFB mode requires ciphertext to have length multiple of block size,
                # but PGP mode allows the last block to be shorter
                if self._done_last_block:
                    raise ValueError("Only the last chunk is allowed to have length not multiple of %d bytes",
                        self.block_size)
                self._done_last_block = True
                padded = ciphertext + b('\x00')*padding_length
                res = self._cipher.decrypt(padded)[:len(ciphertext)]
            else:
                res = self._cipher.decrypt(ciphertext)
            return res

        return self._cipher.decrypt(ciphertext)

