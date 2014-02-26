#
#   ElGamal.py : ElGamal encryption/decryption and signatures
#
#  Part of the Python Cryptography Toolkit
#
#  Originally written by: A.M. Kuchling
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

"""ElGamal public-key algorithm (randomized encryption and signature).

Signature algorithm
-------------------
The security of the ElGamal signature scheme is based (like DSA) on the discrete
logarithm problem (DLP_). Given a cyclic group, a generator *g*,
and an element *h*, it is hard to find an integer *x* such that *g^x = h*.

The group is the largest multiplicative sub-group of the integers modulo *p*,
with *p* prime.
The signer holds a value *x* (*0<x<p-1*) as private key, and its public
key (*y* where *y=g^x mod p*) is distributed.

The ElGamal signature is twice as big as *p*.

Encryption algorithm
--------------------
The security of the ElGamal encryption scheme is based on the computational
Diffie-Hellman problem (CDH_). Given a cyclic group, a generator *g*,
and two integers *a* and *b*, it is difficult to find
the element *g^{ab}* when only *g^a* and *g^b* are known, and not *a* and *b*. 

As before, the group is the largest multiplicative sub-group of the integers
modulo *p*, with *p* prime.
The receiver holds a value *a* (*0<a<p-1*) as private key, and its public key
(*b* where *b*=g^a*) is given to the sender.

The ElGamal ciphertext is twice as big as *p*.

Domain parameters
-----------------
For both signature and encryption schemes, the values *(p,g)* are called
*domain parameters*.
They are not sensitive but must be distributed to all parties (senders and
receivers).
Different signers can share the same domain parameters, as can
different recipients of encrypted messages.

Security
--------
Both DLP and CDH problem are believed to be difficult, and they have been proved
such (and therefore secure) for more than 30 years.

The cryptographic strength is linked to the magnitude of *p*.
In 2012, a sufficient size for *p* is deemed to be 2048 bits.
For more information, see the most recent ECRYPT_ report.

Even though ElGamal algorithms are in theory reasonably secure for new designs,
in practice there are no real good reasons for using them.
The signature is four times larger than the equivalent DSA, and the ciphertext
is two times larger than the equivalent RSA.

Functionality
-------------
This module provides facilities for generating new ElGamal keys and for constructing
them from known components. ElGamal keys allows you to perform basic signing,
verification, encryption, and decryption.

    >>> from Crypto import Random
    >>> from Crypto.Random import random
    >>> from Crypto.PublicKey import ElGamal
    >>> from Crypto.Util.number import GCD
    >>> from Crypto.Hash import SHA
    >>>
    >>> message = "Hello"
    >>> key = ElGamal.generate(1024, Random.new().read)
    >>> h = SHA.new(message).digest()
    >>> while 1:
    >>>     k = random.StrongRandom().randint(1,key.p-1)
    >>>     if GCD(k,key.p-1)==1: break
    >>> sig = key.sign(h,k)
    >>> ...
    >>> if key.verify(h,sig):
    >>>     print "OK"
    >>> else:
    >>>     print "Incorrect signature"

.. _DLP: http://www.cosic.esat.kuleuven.be/publications/talk-78.pdf
.. _CDH: http://en.wikipedia.org/wiki/Computational_Diffie%E2%80%93Hellman_assumption
.. _ECRYPT: http://www.ecrypt.eu.org/documents/D.SPA.17.pdf
"""

__revision__ = "$Id$"

__all__ = ['generate', 'construct', 'error', 'ElGamalobj']

from Crypto.PublicKey.pubkey import *
from Crypto.Util import number

class error (Exception):
    pass

# Generate an ElGamal key with N bits
def generate(bits, randfunc, progress_func=None):
    """Randomly generate a fresh, new ElGamal key.

    The key will be safe for use for both encryption and signature
    (although it should be used for **only one** purpose).

    :Parameters:
        bits : int
            Key length, or size (in bits) of the modulus *p*.
            Recommended value is 2048.
        randfunc : callable
            Random number generation function; it should accept
            a single integer N and return a string of random data
            N bytes long.
        progress_func : callable
            Optional function that will be called with a short string
            containing the key parameter currently being generated;
            it's useful for interactive applications where a user is
            waiting for a key to be generated.

    :attention: You should always use a cryptographically secure random number generator,
        such as the one defined in the ``Crypto.Random`` module; **don't** just use the
        current time and the ``random`` module.

    :Return: An ElGamal key object (`ElGamalobj`).
    """
    obj=ElGamalobj()
    # Generate a safe prime p
    # See Algorithm 4.86 in Handbook of Applied Cryptography
    if progress_func:
        progress_func('p\n')
    while 1:
        q = bignum(getPrime(bits-1, randfunc))
        obj.p = 2*q+1
        if number.isPrime(obj.p, randfunc=randfunc):
            break
    # Generate generator g
    # See Algorithm 4.80 in Handbook of Applied Cryptography
    # Note that the order of the group is n=p-1=2q, where q is prime
    if progress_func:
        progress_func('g\n')
    while 1:
        # We must avoid g=2 because of Bleichenbacher's attack described
        # in "Generating ElGamal signatures without knowning the secret key",
        # 1996
        #
        obj.g = number.getRandomRange(3, obj.p, randfunc)
        safe = 1
        if pow(obj.g, 2, obj.p)==1:
            safe=0
        if safe and pow(obj.g, q, obj.p)==1:
            safe=0
        # Discard g if it divides p-1 because of the attack described
        # in Note 11.67 (iii) in HAC
        if safe and divmod(obj.p-1, obj.g)[1]==0:
            safe=0
        # g^{-1} must not divide p-1 because of Khadir's attack
        # described in "Conditions of the generator for forging ElGamal
        # signature", 2011
        ginv = number.inverse(obj.g, obj.p)
        if safe and divmod(obj.p-1, ginv)[1]==0:
            safe=0
        if safe:
            break
    # Generate private key x
    if progress_func:
        progress_func('x\n')
    obj.x=number.getRandomRange(2, obj.p-1, randfunc)
    # Generate public key y
    if progress_func:
        progress_func('y\n')
    obj.y = pow(obj.g, obj.x, obj.p)
    return obj

def construct(tup):
    """Construct an ElGamal key from a tuple of valid ElGamal components.

    The modulus *p* must be a prime.

    The following conditions must apply:

    - 1 < g < p-1
    - g^{p-1} = 1 mod p
    - 1 < x < p-1
    - g^x = y mod p

    :Parameters:
        tup : tuple
            A tuple of long integers, with 3 or 4 items
            in the following order:

            1. Modulus (*p*).
            2. Generator (*g*).
            3. Public key (*y*).
            4. Private key (*x*). Optional.

    :Return: An ElGamal key object (`ElGamalobj`).
    """

    obj=ElGamalobj()
    if len(tup) not in [3,4]:
        raise ValueError('argument for construct() wrong length')
    for i in range(len(tup)):
        field = obj.keydata[i]
        setattr(obj, field, tup[i])
    return obj

class ElGamalobj(pubkey):
    """Class defining an ElGamal key.

    :undocumented: __getstate__, __setstate__, __repr__, __getattr__
    """

    #: Dictionary of ElGamal parameters.
    #:
    #: A public key will only have the following entries:
    #:
    #:  - **y**, the public key.
    #:  - **g**, the generator.
    #:  - **p**, the modulus.
    #:
    #: A private key will also have:
    #:
    #:  - **x**, the private key.
    keydata=['p', 'g', 'y', 'x']

    def encrypt(self, plaintext, K):
        """Encrypt a piece of data with ElGamal.

        :Parameter plaintext: The piece of data to encrypt with ElGamal.
         It must be numerically smaller than the module (*p*).
        :Type plaintext: byte string or long

        :Parameter K: A secret number, chosen randomly in the closed
         range *[1,p-2]*.
        :Type K: long (recommended) or byte string (not recommended)

        :Return: A tuple with two items. Each item is of the same type as the
         plaintext (string or long).

        :attention: selection of *K* is crucial for security. Generating a
         random number larger than *p-1* and taking the modulus by *p-1* is
         **not** secure, since smaller values will occur more frequently.
         Generating a random number systematically smaller than *p-1*
         (e.g. *floor((p-1)/8)* random bytes) is also **not** secure.
         In general, it shall not be possible for an attacker to know
         the value of any bit of K.

        :attention: The number *K* shall not be reused for any other
         operation and shall be discarded immediately.
        """
        return pubkey.encrypt(self, plaintext, K)
 
    def decrypt(self, ciphertext):
        """Decrypt a piece of data with ElGamal.

        :Parameter ciphertext: The piece of data to decrypt with ElGamal.
        :Type ciphertext: byte string, long or a 2-item tuple as returned
         by `encrypt`

        :Return: A byte string if ciphertext was a byte string or a tuple
         of byte strings. A long otherwise.
        """
        return pubkey.decrypt(self, ciphertext)

    def sign(self, M, K):
        """Sign a piece of data with ElGamal.

        :Parameter M: The piece of data to sign with ElGamal. It may
         not be longer in bit size than *p-1*.
        :Type M: byte string or long

        :Parameter K: A secret number, chosen randomly in the closed
         range *[1,p-2]* and such that *gcd(k,p-1)=1*.
        :Type K: long (recommended) or byte string (not recommended)

        :attention: selection of *K* is crucial for security. Generating a
         random number larger than *p-1* and taking the modulus by *p-1* is
         **not** secure, since smaller values will occur more frequently.
         Generating a random number systematically smaller than *p-1*
         (e.g. *floor((p-1)/8)* random bytes) is also **not** secure.
         In general, it shall not be possible for an attacker to know
         the value of any bit of K.

        :attention: The number *K* shall not be reused for any other
         operation and shall be discarded immediately.

        :attention: M must be be a cryptographic hash, otherwise an
         attacker may mount an existential forgery attack.

        :Return: A tuple with 2 longs.
        """
        return pubkey.sign(self, M, K)

    def verify(self, M, signature):
        """Verify the validity of an ElGamal signature.

        :Parameter M: The expected message.
        :Type M: byte string or long

        :Parameter signature: The ElGamal signature to verify.
        :Type signature: A tuple with 2 longs as return by `sign`

        :Return: True if the signature is correct, False otherwise.
        """
        return pubkey.verify(self, M, signature)

    def _encrypt(self, M, K):
        a=pow(self.g, K, self.p)
        b=( M*pow(self.y, K, self.p) ) % self.p
        return ( a,b )

    def _decrypt(self, M):
        if (not hasattr(self, 'x')):
            raise TypeError('Private key not available in this object')
        ax=pow(M[0], self.x, self.p)
        plaintext=(M[1] * inverse(ax, self.p ) ) % self.p
        return plaintext

    def _sign(self, M, K):
        if (not hasattr(self, 'x')):
            raise TypeError('Private key not available in this object')
        p1=self.p-1
        if (GCD(K, p1)!=1):
            raise ValueError('Bad K value: GCD(K,p-1)!=1')
        a=pow(self.g, K, self.p)
        t=(M-self.x*a) % p1
        while t<0: t=t+p1
        b=(t*inverse(K, p1)) % p1
        return (a, b)

    def _verify(self, M, sig):
        if sig[0]<1 or sig[0]>self.p-1:
            return 0
        v1=pow(self.y, sig[0], self.p)
        v1=(v1*pow(sig[0], sig[1], self.p)) % self.p
        v2=pow(self.g, M, self.p)
        if v1==v2:
            return 1
        return 0

    def size(self):
        return number.size(self.p) - 1

    def has_private(self):
        if hasattr(self, 'x'):
            return 1
        else:
            return 0

    def publickey(self):
        return construct((self.p, self.g, self.y))


object=ElGamalobj
