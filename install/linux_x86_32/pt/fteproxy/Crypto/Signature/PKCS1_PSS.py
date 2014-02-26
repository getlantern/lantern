# -*- coding: utf-8 -*-
#
#  Signature/PKCS1_PSS.py : PKCS#1 PPS
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

"""RSA digital signature protocol with appendix according to PKCS#1 PSS.

See RFC3447__ or the `original RSA Labs specification`__.

This scheme is more properly called ``RSASSA-PSS``.

For example, a sender may authenticate a message using SHA-1 and PSS like
this:

    >>> from Crypto.Signature import PKCS1_PSS
    >>> from Crypto.Hash import SHA
    >>> from Crypto.PublicKey import RSA
    >>> from Crypto import Random
    >>>
    >>> message = 'To be signed'
    >>> key = RSA.importKey(open('privkey.der').read())
    >>> h = SHA.new()
    >>> h.update(message)
    >>> signer = PKCS1_PSS.new(key)
    >>> signature = PKCS1_PSS.sign(key)

At the receiver side, verification can be done like using the public part of
the RSA key:

    >>> key = RSA.importKey(open('pubkey.der').read())
    >>> h = SHA.new()
    >>> h.update(message)
    >>> verifier = PKCS1_PSS.new(key)
    >>> if verifier.verify(h, signature):
    >>>     print "The signature is authentic."
    >>> else:
    >>>     print "The signature is not authentic."

:undocumented: __revision__, __package__

.. __: http://www.ietf.org/rfc/rfc3447.txt
.. __: http://www.rsa.com/rsalabs/node.asp?id=2125
"""

# Allow nested scopes in Python 2.1
# See http://oreilly.com/pub/a/python/2001/04/19/pythonnews.html
from __future__ import nested_scopes

__revision__ = "$Id$"
__all__ = [ 'new', 'PSS_SigScheme' ]

from Crypto.Util.py3compat import *
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *
import Crypto.Util.number
from Crypto.Util.number import ceil_shift, ceil_div, long_to_bytes
from Crypto.Util.strxor import strxor

class PSS_SigScheme:
    """This signature scheme can perform PKCS#1 PSS RSA signature or verification."""

    def __init__(self, key, mgfunc, saltLen):
        """Initialize this PKCS#1 PSS signature scheme object.
        
        :Parameters:
         key : an RSA key object
                If a private half is given, both signature and verification are possible.
                If a public half is given, only verification is possible.
         mgfunc : callable
                A mask generation function that accepts two parameters: a string to
                use as seed, and the lenth of the mask to generate, in bytes.
         saltLen : int
                Length of the salt, in bytes.
        """
        self._key = key
        self._saltLen = saltLen
        self._mgfunc = mgfunc

    def can_sign(self):
        """Return True if this cipher object can be used for signing messages."""
        return self._key.has_private()
 
    def sign(self, mhash):
        """Produce the PKCS#1 PSS signature of a message.
    
        This function is named ``RSASSA-PSS-SIGN``, and is specified in
        section 8.1.1 of RFC3447.
    
        :Parameters:
         mhash : hash object
                The hash that was carried out over the message. This is an object
                belonging to the `Crypto.Hash` module.
   
        :Return: The PSS signature encoded as a string.
        :Raise ValueError:
            If the RSA key length is not sufficiently long to deal with the given
            hash algorithm.
        :Raise TypeError:
            If the RSA key has no private half.
    
        :attention: Modify the salt length and the mask generation function only
                    if you know what you are doing.
                    The receiver must use the same parameters too.
        """
        # TODO: Verify the key is RSA
    
        randfunc = self._key._randfunc
        
        # Set defaults for salt length and mask generation function
        if self._saltLen == None:
            sLen = mhash.digest_size
        else:
            sLen = self._saltLen
        if self._mgfunc:
            mgf = self._mgfunc
        else:
             mgf  = lambda x,y: MGF1(x,y,mhash)
 
        modBits = Crypto.Util.number.size(self._key.n)
    
        # See 8.1.1 in RFC3447
        k = ceil_div(modBits,8) # Convert from bits to bytes
        # Step 1
        em = EMSA_PSS_ENCODE(mhash, modBits-1, randfunc, mgf, sLen)
        # Step 2a (OS2IP) and 2b (RSASP1)
        m = self._key.decrypt(em)
        # Step 2c (I2OSP)
        S = bchr(0x00)*(k-len(m)) + m
        return S
    
    def verify(self, mhash, S):
        """Verify that a certain PKCS#1 PSS signature is authentic.
    
        This function checks if the party holding the private half of the given
        RSA key has really signed the message.
    
        This function is called ``RSASSA-PSS-VERIFY``, and is specified in section
        8.1.2 of RFC3447.
    
        :Parameters:
         mhash : hash object
                The hash that was carried out over the message. This is an object
                belonging to the `Crypto.Hash` module.
         S : string
                The signature that needs to be validated.
    
        :Return: True if verification is correct. False otherwise.
        """
        # TODO: Verify the key is RSA
    
        # Set defaults for salt length and mask generation function
        if self._saltLen == None:
            sLen = mhash.digest_size
        else:
            sLen = self._saltLen
        if self._mgfunc:
            mgf = self._mgfunc
        else:
            mgf  = lambda x,y: MGF1(x,y,mhash)

        modBits = Crypto.Util.number.size(self._key.n)
    
        # See 8.1.2 in RFC3447
        k = ceil_div(modBits,8) # Convert from bits to bytes
        # Step 1
        if len(S) != k:
            return False
        # Step 2a (O2SIP), 2b (RSAVP1), and partially 2c (I2OSP)
        # Note that signature must be smaller than the module
        # but RSA.py won't complain about it.
        # TODO: Fix RSA object; don't do it here.
        em = self._key.encrypt(S, 0)[0]
        # Step 2c
        emLen = ceil_div(modBits-1,8)
        em = bchr(0x00)*(emLen-len(em)) + em
        # Step 3
        try:
            result = EMSA_PSS_VERIFY(mhash, em, modBits-1, mgf, sLen)
        except ValueError:
            return False
        # Step 4
        return result
    
def MGF1(mgfSeed, maskLen, hash):
    """Mask Generation Function, described in B.2.1"""
    T = b("")
    for counter in xrange(ceil_div(maskLen, hash.digest_size)):
        c = long_to_bytes(counter, 4)
        T = T + hash.new(mgfSeed + c).digest()
    assert(len(T)>=maskLen)
    return T[:maskLen]

def EMSA_PSS_ENCODE(mhash, emBits, randFunc, mgf, sLen):
    """
    Implement the ``EMSA-PSS-ENCODE`` function, as defined
    in PKCS#1 v2.1 (RFC3447, 9.1.1).

    The original ``EMSA-PSS-ENCODE`` actually accepts the message ``M`` as input,
    and hash it internally. Here, we expect that the message has already
    been hashed instead.

    :Parameters:
     mhash : hash object
            The hash object that holds the digest of the message being signed.
     emBits : int
            Maximum length of the final encoding, in bits.
     randFunc : callable
            An RNG function that accepts as only parameter an int, and returns
            a string of random bytes, to be used as salt.
     mgf : callable
            A mask generation function that accepts two parameters: a string to
            use as seed, and the lenth of the mask to generate, in bytes.
     sLen : int
            Length of the salt, in bytes.

    :Return: An ``emLen`` byte long string that encodes the hash
            (with ``emLen = \ceil(emBits/8)``).

    :Raise ValueError:
        When digest or salt length are too big.
    """

    emLen = ceil_div(emBits,8)

    # Bitmask of digits that fill up
    lmask = 0
    for i in xrange(8*emLen-emBits):
        lmask = lmask>>1 | 0x80

    # Step 1 and 2 have been already done
    # Step 3
    if emLen < mhash.digest_size+sLen+2:
        raise ValueError("Digest or salt length are too long for given key size.")
    # Step 4
    salt = b("")
    if randFunc and sLen>0:
        salt = randFunc(sLen)
    # Step 5 and 6
    h = mhash.new(bchr(0x00)*8 + mhash.digest() + salt)
    # Step 7 and 8
    db = bchr(0x00)*(emLen-sLen-mhash.digest_size-2) + bchr(0x01) + salt
    # Step 9
    dbMask = mgf(h.digest(), emLen-mhash.digest_size-1)
    # Step 10
    maskedDB = strxor(db,dbMask)
    # Step 11
    maskedDB = bchr(bord(maskedDB[0]) & ~lmask) + maskedDB[1:]
    # Step 12
    em = maskedDB + h.digest() + bchr(0xBC)
    return em

def EMSA_PSS_VERIFY(mhash, em, emBits, mgf, sLen):
    """
    Implement the ``EMSA-PSS-VERIFY`` function, as defined
    in PKCS#1 v2.1 (RFC3447, 9.1.2).

    ``EMSA-PSS-VERIFY`` actually accepts the message ``M`` as input,
    and hash it internally. Here, we expect that the message has already
    been hashed instead.

    :Parameters:
     mhash : hash object
            The hash object that holds the digest of the message to be verified.
     em : string
            The signature to verify, therefore proving that the sender really signed
            the message that was received.
     emBits : int
            Length of the final encoding (em), in bits.
     mgf : callable
            A mask generation function that accepts two parameters: a string to
            use as seed, and the lenth of the mask to generate, in bytes.
     sLen : int
            Length of the salt, in bytes.

    :Return: 0 if the encoding is consistent, 1 if it is inconsistent.

    :Raise ValueError:
        When digest or salt length are too big.
    """

    emLen = ceil_div(emBits,8)

    # Bitmask of digits that fill up
    lmask = 0
    for i in xrange(8*emLen-emBits):
        lmask = lmask>>1 | 0x80

    # Step 1 and 2 have been already done
    # Step 3
    if emLen < mhash.digest_size+sLen+2:
        return False
    # Step 4
    if ord(em[-1:])!=0xBC:
        return False
    # Step 5
    maskedDB = em[:emLen-mhash.digest_size-1]
    h = em[emLen-mhash.digest_size-1:-1]
    # Step 6
    if lmask & bord(em[0]):
        return False
    # Step 7
    dbMask = mgf(h, emLen-mhash.digest_size-1)
    # Step 8
    db = strxor(maskedDB, dbMask)
    # Step 9
    db = bchr(bord(db[0]) & ~lmask) + db[1:]
    # Step 10
    if not db.startswith(bchr(0x00)*(emLen-mhash.digest_size-sLen-2) + bchr(0x01)):
        return False
    # Step 11
    salt = b("")
    if sLen: salt = db[-sLen:]
    # Step 12 and 13
    hp = mhash.new(bchr(0x00)*8 + mhash.digest() + salt).digest()
    # Step 14
    if h!=hp:
        return False
    return True

def new(key, mgfunc=None, saltLen=None):
    """Return a signature scheme object `PSS_SigScheme` that
    can be used to perform PKCS#1 PSS signature or verification.

    :Parameters:
     key : RSA key object
        The key to use to sign or verify the message. This is a `Crypto.PublicKey.RSA` object.
        Signing is only possible if *key* is a private RSA key.
     mgfunc : callable
        A mask generation function that accepts two parameters: a string to
        use as seed, and the lenth of the mask to generate, in bytes.
        If not specified, the standard MGF1 is used.
     saltLen : int
        Length of the salt, in bytes. If not specified, it matches the output
        size of the hash function.
 
    """
    return PSS_SigScheme(key, mgfunc, saltLen)

