# -*- coding: utf-8 -*-
#
#  Cipher/PKCS1_OAEP.py : PKCS#1 OAEP
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

"""RSA encryption protocol according to PKCS#1 OAEP

See RFC3447__ or the `original RSA Labs specification`__ .

This scheme is more properly called ``RSAES-OAEP``.

As an example, a sender may encrypt a message in this way:

        >>> from Crypto.Cipher import PKCS1_OAEP
        >>> from Crypto.PublicKey import RSA
        >>>
        >>> message = 'To be encrypted'
        >>> key = RSA.importKey(open('pubkey.der').read())
        >>> cipher = PKCS1_OAEP.new(key)
        >>> ciphertext = cipher.encrypt(message)

At the receiver side, decryption can be done using the private part of
the RSA key:

        >>> key = RSA.importKey(open('privkey.der').read())
        >>> cipher = PKCS1_OAP.new(key)
        >>> message = cipher.decrypt(ciphertext)

:undocumented: __revision__, __package__

.. __: http://www.ietf.org/rfc/rfc3447.txt
.. __: http://www.rsa.com/rsalabs/node.asp?id=2125.
"""

from __future__ import nested_scopes

__revision__ = "$Id$"
__all__ = [ 'new', 'PKCS1OAEP_Cipher' ]

import Crypto.Signature.PKCS1_PSS
import Crypto.Hash.SHA

from Crypto.Util.py3compat import *
import Crypto.Util.number
from   Crypto.Util.number import ceil_div
from   Crypto.Util.strxor import strxor

class PKCS1OAEP_Cipher:
    """This cipher can perform PKCS#1 v1.5 OAEP encryption or decryption."""

    def __init__(self, key, hashAlgo, mgfunc, label):
        """Initialize this PKCS#1 OAEP cipher object.
        
        :Parameters:
         key : an RSA key object
          If a private half is given, both encryption and decryption are possible.
          If a public half is given, only encryption is possible.
         hashAlgo : hash object
                The hash function to use. This can be a module under `Crypto.Hash`
                or an existing hash object created from any of such modules. If not specified,
                `Crypto.Hash.SHA` (that is, SHA-1) is used.
         mgfunc : callable
                A mask generation function that accepts two parameters: a string to
                use as seed, and the lenth of the mask to generate, in bytes.
                If not specified, the standard MGF1 is used (a safe choice).
         label : string
                A label to apply to this particular encryption. If not specified,
                an empty string is used. Specifying a label does not improve
                security.
 
        :attention: Modify the mask generation function only if you know what you are doing.
                    Sender and receiver must use the same one.
        """
        self._key = key

        if hashAlgo:
            self._hashObj = hashAlgo
        else:
            self._hashObj = Crypto.Hash.SHA

        if mgfunc:
            self._mgf = mgfunc
        else:
            self._mgf = lambda x,y: Crypto.Signature.PKCS1_PSS.MGF1(x,y,self._hashObj)

        self._label = label

    def can_encrypt(self):
        """Return True/1 if this cipher object can be used for encryption."""
        return self._key.can_encrypt()

    def can_decrypt(self):
        """Return True/1 if this cipher object can be used for decryption."""
        return self._key.can_decrypt()

    def encrypt(self, message):
        """Produce the PKCS#1 OAEP encryption of a message.
    
        This function is named ``RSAES-OAEP-ENCRYPT``, and is specified in
        section 7.1.1 of RFC3447.
    
        :Parameters:
         message : string
                The message to encrypt, also known as plaintext. It can be of
                variable length, but not longer than the RSA modulus (in bytes)
                minus 2, minus twice the hash output size.
   
        :Return: A string, the ciphertext in which the message is encrypted.
            It is as long as the RSA modulus (in bytes).
        :Raise ValueError:
            If the RSA key length is not sufficiently long to deal with the given
            message.
        """
        # TODO: Verify the key is RSA
    
        randFunc = self._key._randfunc
    
        # See 7.1.1 in RFC3447
        modBits = Crypto.Util.number.size(self._key.n)
        k = ceil_div(modBits,8) # Convert from bits to bytes
        hLen = self._hashObj.digest_size
        mLen = len(message)
    
        # Step 1b
        ps_len = k-mLen-2*hLen-2
        if ps_len<0:
            raise ValueError("Plaintext is too long.")
        # Step 2a
        lHash = self._hashObj.new(self._label).digest()
        # Step 2b
        ps = bchr(0x00)*ps_len
        # Step 2c
        db = lHash + ps + bchr(0x01) + message
        # Step 2d
        ros = randFunc(hLen)
        # Step 2e
        dbMask = self._mgf(ros, k-hLen-1)
        # Step 2f
        maskedDB = strxor(db, dbMask)
        # Step 2g
        seedMask = self._mgf(maskedDB, hLen)
        # Step 2h
        maskedSeed = strxor(ros, seedMask)
        # Step 2i
        em = bchr(0x00) + maskedSeed + maskedDB
        # Step 3a (OS2IP), step 3b (RSAEP), part of step 3c (I2OSP)
        m = self._key.encrypt(em, 0)[0]
        # Complete step 3c (I2OSP)
        c = bchr(0x00)*(k-len(m)) + m
        return c
    
    def decrypt(self, ct):
        """Decrypt a PKCS#1 OAEP ciphertext.
    
        This function is named ``RSAES-OAEP-DECRYPT``, and is specified in
        section 7.1.2 of RFC3447.
    
        :Parameters:
         ct : string
                The ciphertext that contains the message to recover.
   
        :Return: A string, the original message.
        :Raise ValueError:
            If the ciphertext length is incorrect, or if the decryption does not
            succeed.
        :Raise TypeError:
            If the RSA key has no private half.
        """
        # TODO: Verify the key is RSA
    
        # See 7.1.2 in RFC3447
        modBits = Crypto.Util.number.size(self._key.n)
        k = ceil_div(modBits,8) # Convert from bits to bytes
        hLen = self._hashObj.digest_size
    
        # Step 1b and 1c
        if len(ct) != k or k<hLen+2:
            raise ValueError("Ciphertext with incorrect length.")
        # Step 2a (O2SIP), 2b (RSADP), and part of 2c (I2OSP)
        m = self._key.decrypt(ct)
        # Complete step 2c (I2OSP)
        em = bchr(0x00)*(k-len(m)) + m
        # Step 3a
        lHash = self._hashObj.new(self._label).digest()
        # Step 3b
        y = em[0]
        # y must be 0, but we MUST NOT check it here in order not to
        # allow attacks like Manger's (http://dl.acm.org/citation.cfm?id=704143)
        maskedSeed = em[1:hLen+1]
        maskedDB = em[hLen+1:]
        # Step 3c
        seedMask = self._mgf(maskedDB, hLen)
        # Step 3d
        seed = strxor(maskedSeed, seedMask)
        # Step 3e
        dbMask = self._mgf(seed, k-hLen-1)
        # Step 3f
        db = strxor(maskedDB, dbMask)
        # Step 3g
        valid = 1
        one = db[hLen:].find(bchr(0x01))
        lHash1 = db[:hLen]
        if lHash1!=lHash:
            valid = 0
        if one<0:
            valid = 0
        if bord(y)!=0:
            valid = 0
        if not valid:
            raise ValueError("Incorrect decryption.")
        # Step 4
        return db[hLen+one+1:]

def new(key, hashAlgo=None, mgfunc=None, label=b('')):
    """Return a cipher object `PKCS1OAEP_Cipher` that can be used to perform PKCS#1 OAEP encryption or decryption.

    :Parameters:
     key : RSA key object
      The key to use to encrypt or decrypt the message. This is a `Crypto.PublicKey.RSA` object.
      Decryption is only possible if *key* is a private RSA key.
     hashAlgo : hash object
      The hash function to use. This can be a module under `Crypto.Hash`
      or an existing hash object created from any of such modules. If not specified,
      `Crypto.Hash.SHA` (that is, SHA-1) is used.
     mgfunc : callable
      A mask generation function that accepts two parameters: a string to
      use as seed, and the lenth of the mask to generate, in bytes.
      If not specified, the standard MGF1 is used (a safe choice).
     label : string
      A label to apply to this particular encryption. If not specified,
      an empty string is used. Specifying a label does not improve
      security.
 
    :attention: Modify the mask generation function only if you know what you are doing.
      Sender and receiver must use the same one.
    """
    return PKCS1OAEP_Cipher(key, hashAlgo, mgfunc, label)

