# -*- coding: utf-8 -*-
#
#  Signature/PKCS1-v1_5.py : PKCS#1 v1.5
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

"""
RSA digital signature protocol according to PKCS#1 v1.5

See RFC3447__ or the `original RSA Labs specification`__.

This scheme is more properly called ``RSASSA-PKCS1-v1_5``.

For example, a sender may authenticate a message using SHA-1 like
this:

        >>> from Crypto.Signature import PKCS1_v1_5
        >>> from Crypto.Hash import SHA
        >>> from Crypto.PublicKey import RSA
        >>>
        >>> message = 'To be signed'
        >>> key = RSA.importKey(open('privkey.der').read())
        >>> h = SHA.new(message)
        >>> signer = PKCS1_v1_5.new(key)
        >>> signature = signer.sign(h)

At the receiver side, verification can be done using the public part of
the RSA key:

        >>> key = RSA.importKey(open('pubkey.der').read())
        >>> h = SHA.new(message)
        >>> verifier = PKCS1_v1_5.new(key)
        >>> if verifier.verify(h, signature):
        >>>    print "The signature is authentic."
        >>> else:
        >>>    print "The signature is not authentic."

:undocumented: __revision__, __package__

.. __: http://www.ietf.org/rfc/rfc3447.txt
.. __: http://www.rsa.com/rsalabs/node.asp?id=2125
"""

__revision__ = "$Id$"
__all__ = [ 'new', 'PKCS115_SigScheme' ]

import Crypto.Util.number
from Crypto.Util.number import ceil_div
from Crypto.Util.asn1 import DerSequence, DerNull, DerOctetString
from Crypto.Util.py3compat import *

class PKCS115_SigScheme:
    """This signature scheme can perform PKCS#1 v1.5 RSA signature or verification."""

    def __init__(self, key):
        """Initialize this PKCS#1 v1.5 signature scheme object.
        
        :Parameters:
         key : an RSA key object
          If a private half is given, both signature and verification are possible.
          If a public half is given, only verification is possible.
        """
        self._key = key

    def can_sign(self):
        """Return True if this cipher object can be used for signing messages."""
        return self._key.has_private()

    def sign(self, mhash):
        """Produce the PKCS#1 v1.5 signature of a message.
    
        This function is named ``RSASSA-PKCS1-V1_5-SIGN``, and is specified in
        section 8.2.1 of RFC3447.
    
        :Parameters:
         mhash : hash object
                The hash that was carried out over the message. This is an object
                belonging to the `Crypto.Hash` module.
    
        :Return: The signature encoded as a string.
        :Raise ValueError:
            If the RSA key length is not sufficiently long to deal with the given
            hash algorithm.
        :Raise TypeError:
            If the RSA key has no private half.
        """
        # TODO: Verify the key is RSA
    
        # See 8.2.1 in RFC3447
        modBits = Crypto.Util.number.size(self._key.n)
        k = ceil_div(modBits,8) # Convert from bits to bytes
    
        # Step 1
        em = EMSA_PKCS1_V1_5_ENCODE(mhash, k)
        # Step 2a (OS2IP) and 2b (RSASP1)
        m = self._key.decrypt(em)
        # Step 2c (I2OSP)
        S = bchr(0x00)*(k-len(m)) + m
        return S
    
    def verify(self, mhash, S):
        """Verify that a certain PKCS#1 v1.5 signature is authentic.
    
        This function checks if the party holding the private half of the key
        really signed the message.
    
        This function is named ``RSASSA-PKCS1-V1_5-VERIFY``, and is specified in
        section 8.2.2 of RFC3447.
    
        :Parameters:
         mhash : hash object
                The hash that was carried out over the message. This is an object
                belonging to the `Crypto.Hash` module.
         S : string
                The signature that needs to be validated.
    
        :Return: True if verification is correct. False otherwise.
        """
        # TODO: Verify the key is RSA
    
        # See 8.2.2 in RFC3447
        modBits = Crypto.Util.number.size(self._key.n)
        k = ceil_div(modBits,8) # Convert from bits to bytes
    
        # Step 1
        if len(S) != k:
            return 0
        # Step 2a (O2SIP) and 2b (RSAVP1)
        # Note that signature must be smaller than the module
        # but RSA.py won't complain about it.
        # TODO: Fix RSA object; don't do it here.
        m = self._key.encrypt(S, 0)[0]
        # Step 2c (I2OSP)
        em1 = bchr(0x00)*(k-len(m)) + m
        # Step 3
        try:
            em2 = EMSA_PKCS1_V1_5_ENCODE(mhash, k)
        except ValueError:
            return 0
        # Step 4
        # By comparing the full encodings (as opposed to checking each
        # of its components one at a time) we avoid attacks to the padding
        # scheme like Bleichenbacher's (see http://www.mail-archive.com/cryptography@metzdowd.com/msg06537).
        # 
        return em1==em2
    
def EMSA_PKCS1_V1_5_ENCODE(hash, emLen):
    """
    Implement the ``EMSA-PKCS1-V1_5-ENCODE`` function, as defined
    in PKCS#1 v2.1 (RFC3447, 9.2).

    ``EMSA-PKCS1-V1_5-ENCODE`` actually accepts the message ``M`` as input,
    and hash it internally. Here, we expect that the message has already
    been hashed instead.

    :Parameters:
     hash : hash object
            The hash object that holds the digest of the message being signed.
     emLen : int
            The length the final encoding must have, in bytes.

    :attention: the early standard (RFC2313) stated that ``DigestInfo``
        had to be BER-encoded. This means that old signatures
        might have length tags in indefinite form, which
        is not supported in DER. Such encoding cannot be
        reproduced by this function.

    :attention: the same standard defined ``DigestAlgorithm`` to be
        of ``AlgorithmIdentifier`` type, where the PARAMETERS
        item is optional. Encodings for ``MD2/4/5`` without
        ``PARAMETERS`` cannot be reproduced by this function.

    :Return: An ``emLen`` byte long string that encodes the hash.
    """

    # First, build the ASN.1 DER object DigestInfo:
    #
    #   DigestInfo ::= SEQUENCE {
    #       digestAlgorithm AlgorithmIdentifier,
    #       digest OCTET STRING
    #   }
    #
    # where digestAlgorithm identifies the hash function and shall be an
    # algorithm ID with an OID in the set PKCS1-v1-5DigestAlgorithms.
    #
    #   PKCS1-v1-5DigestAlgorithms    ALGORITHM-IDENTIFIER ::= {
    #       { OID id-md2 PARAMETERS NULL    }|
    #       { OID id-md5 PARAMETERS NULL    }|
    #       { OID id-sha1 PARAMETERS NULL   }|
    #       { OID id-sha256 PARAMETERS NULL }|
    #       { OID id-sha384 PARAMETERS NULL }|
    #       { OID id-sha512 PARAMETERS NULL }
    #   }
    #
    digestAlgo  = DerSequence([hash.oid, DerNull().encode()])
    digest      = DerOctetString(hash.digest())
    digestInfo  = DerSequence([
                    digestAlgo.encode(),
                    digest.encode()
                    ]).encode()

    # We need at least 11 bytes for the remaining data: 3 fixed bytes and
    # at least 8 bytes of padding).
    if emLen<len(digestInfo)+11:
        raise ValueError("Selected hash algorith has a too long digest (%d bytes)." % len(digest))
    PS = bchr(0xFF) * (emLen - len(digestInfo) - 3)
    return b("\x00\x01") + PS + bchr(0x00) + digestInfo

def new(key):
    """Return a signature scheme object `PKCS115_SigScheme` that
    can be used to perform PKCS#1 v1.5 signature or verification.

    :Parameters:
     key : RSA key object
      The key to use to sign or verify the message. This is a `Crypto.PublicKey.RSA` object.
      Signing is only possible if *key* is a private RSA key.

    """
    return PKCS115_SigScheme(key)

