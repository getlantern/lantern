# -*- coding: utf-8 -*-
#
#  PublicKey/DSA.py : DSA signature primitive
#
# Written in 2008 by Dwayne C. Litzenberger <dlitz@dlitz.net>
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

"""DSA public-key signature algorithm.

DSA_ is a widespread public-key signature algorithm. Its security is
based on the discrete logarithm problem (DLP_). Given a cyclic
group, a generator *g*, and an element *h*, it is hard
to find an integer *x* such that *g^x = h*. The problem is believed
to be difficult, and it has been proved such (and therefore secure) for
more than 30 years.

The group is actually a sub-group over the integers modulo *p*, with *p* prime.
The sub-group order is *q*, which is prime too; it always holds that *(p-1)* is a multiple of *q*.
The cryptographic strength is linked to the magnitude of *p* and *q*.
The signer holds a value *x* (*0<x<q-1*) as private key, and its public
key (*y* where *y=g^x mod p*) is distributed.

In 2012, a sufficient size is deemed to be 2048 bits for *p* and 256 bits for *q*.
For more information, see the most recent ECRYPT_ report.

DSA is reasonably secure for new designs.

The algorithm can only be used for authentication (digital signature).
DSA cannot be used for confidentiality (encryption).

The values *(p,q,g)* are called *domain parameters*;
they are not sensitive but must be shared by both parties (the signer and the verifier).
Different signers can share the same domain parameters with no security
concerns.

The DSA signature is twice as big as the size of *q* (64 bytes if *q* is 256 bit
long).

This module provides facilities for generating new DSA keys and for constructing
them from known components. DSA keys allows you to perform basic signing and
verification.

    >>> from Crypto.Random import random
    >>> from Crypto.PublicKey import DSA
    >>> from Crypto.Hash import SHA
    >>>
    >>> message = "Hello"
    >>> key = DSA.generate(1024)
    >>> h = SHA.new(message).digest()
    >>> k = random.StrongRandom().randint(1,key.q-1)
    >>> sig = key.sign(h,k)
    >>> ...
    >>> if key.verify(h,sig):
    >>>     print "OK"
    >>> else:
    >>>     print "Incorrect signature"

.. _DSA: http://en.wikipedia.org/wiki/Digital_Signature_Algorithm
.. _DLP: http://www.cosic.esat.kuleuven.be/publications/talk-78.pdf
.. _ECRYPT: http://www.ecrypt.eu.org/documents/D.SPA.17.pdf
"""

__revision__ = "$Id$"

__all__ = ['generate', 'construct', 'error', 'DSAImplementation', '_DSAobj']

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *

from Crypto.PublicKey import _DSA, _slowmath, pubkey
from Crypto import Random

try:
    from Crypto.PublicKey import _fastmath
except ImportError:
    _fastmath = None

class _DSAobj(pubkey.pubkey):
    """Class defining an actual DSA key.

    :undocumented: __getstate__, __setstate__, __repr__, __getattr__
    """
    #: Dictionary of DSA parameters.
    #:
    #: A public key will only have the following entries:
    #:
    #:  - **y**, the public key.
    #:  - **g**, the generator.
    #:  - **p**, the modulus.
    #:  - **q**, the order of the sub-group.
    #:
    #: A private key will also have:
    #:
    #:  - **x**, the private key.
    keydata = ['y', 'g', 'p', 'q', 'x']

    def __init__(self, implementation, key):
        self.implementation = implementation
        self.key = key

    def __getattr__(self, attrname):
        if attrname in self.keydata:
            # For backward compatibility, allow the user to get (not set) the
            # DSA key parameters directly from this object.
            return getattr(self.key, attrname)
        else:
            raise AttributeError("%s object has no %r attribute" % (self.__class__.__name__, attrname,))

    def sign(self, M, K):
        """Sign a piece of data with DSA.

        :Parameter M: The piece of data to sign with DSA. It may
         not be longer in bit size than the sub-group order (*q*).
        :Type M: byte string or long

        :Parameter K: A secret number, chosen randomly in the closed
         range *[1,q-1]*.
        :Type K: long (recommended) or byte string (not recommended)

        :attention: selection of *K* is crucial for security. Generating a
         random number larger than *q* and taking the modulus by *q* is
         **not** secure, since smaller values will occur more frequently.
         Generating a random number systematically smaller than *q-1*
         (e.g. *floor((q-1)/8)* random bytes) is also **not** secure. In general,
         it shall not be possible for an attacker to know the value of `any
         bit of K`__.

        :attention: The number *K* shall not be reused for any other
         operation and shall be discarded immediately.

        :attention: M must be a digest cryptographic hash, otherwise
         an attacker may mount an existential forgery attack.

        :Return: A tuple with 2 longs.

        .. __: http://www.di.ens.fr/~pnguyen/pub_NgSh00.htm
        """
        return pubkey.pubkey.sign(self, M, K)

    def verify(self, M, signature):
        """Verify the validity of a DSA signature.

        :Parameter M: The expected message.
        :Type M: byte string or long

        :Parameter signature: The DSA signature to verify.
        :Type signature: A tuple with 2 longs as return by `sign`

        :Return: True if the signature is correct, False otherwise.
        """
        return pubkey.pubkey.verify(self, M, signature)

    def _encrypt(self, c, K):
        raise TypeError("DSA cannot encrypt")

    def _decrypt(self, c):
        raise TypeError("DSA cannot decrypt")

    def _blind(self, m, r):
        raise TypeError("DSA cannot blind")

    def _unblind(self, m, r):
        raise TypeError("DSA cannot unblind")

    def _sign(self, m, k):
        return self.key._sign(m, k)

    def _verify(self, m, sig):
        (r, s) = sig
        return self.key._verify(m, r, s)

    def has_private(self):
        return self.key.has_private()

    def size(self):
        return self.key.size()

    def can_blind(self):
        return False

    def can_encrypt(self):
        return False

    def can_sign(self):
        return True

    def publickey(self):
        return self.implementation.construct((self.key.y, self.key.g, self.key.p, self.key.q))

    def __getstate__(self):
        d = {}
        for k in self.keydata:
            try:
                d[k] = getattr(self.key, k)
            except AttributeError:
                pass
        return d

    def __setstate__(self, d):
        if not hasattr(self, 'implementation'):
            self.implementation = DSAImplementation()
        t = []
        for k in self.keydata:
            if not d.has_key(k):
                break
            t.append(d[k])
        self.key = self.implementation._math.dsa_construct(*tuple(t))

    def __repr__(self):
        attrs = []
        for k in self.keydata:
            if k == 'p':
                attrs.append("p(%d)" % (self.size()+1,))
            elif hasattr(self.key, k):
                attrs.append(k)
        if self.has_private():
            attrs.append("private")
        # PY3K: This is meant to be text, do not change to bytes (data)
        return "<%s @0x%x %s>" % (self.__class__.__name__, id(self), ",".join(attrs))

class DSAImplementation(object):
    """
    A DSA key factory.

    This class is only internally used to implement the methods of the
    `Crypto.PublicKey.DSA` module.
    """
 
    def __init__(self, **kwargs):
        """Create a new DSA key factory.

        :Keywords:
         use_fast_math : bool
                                Specify which mathematic library to use:

                                - *None* (default). Use fastest math available.
                                - *True* . Use fast math.
                                - *False* . Use slow math.
         default_randfunc : callable
                                Specify how to collect random data:

                                - *None* (default). Use Random.new().read().
                                - not *None* . Use the specified function directly.
        :Raise RuntimeError:
            When **use_fast_math** =True but fast math is not available.
        """
        use_fast_math = kwargs.get('use_fast_math', None)
        if use_fast_math is None:   # Automatic
            if _fastmath is not None:
                self._math = _fastmath
            else:
                self._math = _slowmath

        elif use_fast_math:     # Explicitly select fast math
            if _fastmath is not None:
                self._math = _fastmath
            else:
                raise RuntimeError("fast math module not available")

        else:   # Explicitly select slow math
            self._math = _slowmath

        self.error = self._math.error

        # 'default_randfunc' parameter:
        #   None (default) - use Random.new().read
        #   not None       - use the specified function
        self._default_randfunc = kwargs.get('default_randfunc', None)
        self._current_randfunc = None

    def _get_randfunc(self, randfunc):
        if randfunc is not None:
            return randfunc
        elif self._current_randfunc is None:
            self._current_randfunc = Random.new().read
        return self._current_randfunc

    def generate(self, bits, randfunc=None, progress_func=None):
        """Randomly generate a fresh, new DSA key.

        :Parameters:
         bits : int
                            Key length, or size (in bits) of the DSA modulus
                            *p*.
                            It must be a multiple of 64, in the closed
                            interval [512,1024].
         randfunc : callable
                            Random number generation function; it should accept
                            a single integer N and return a string of random data
                            N bytes long.
                            If not specified, a new one will be instantiated
                            from ``Crypto.Random``.
         progress_func : callable
                            Optional function that will be called with a short string
                            containing the key parameter currently being generated;
                            it's useful for interactive applications where a user is
                            waiting for a key to be generated.

        :attention: You should always use a cryptographically secure random number generator,
            such as the one defined in the ``Crypto.Random`` module; **don't** just use the
            current time and the ``random`` module.

        :Return: A DSA key object (`_DSAobj`).

        :Raise ValueError:
            When **bits** is too little, too big, or not a multiple of 64.
        """
 
        # Check against FIPS 186-2, which says that the size of the prime p
        # must be a multiple of 64 bits between 512 and 1024
        for i in (0, 1, 2, 3, 4, 5, 6, 7, 8):
            if bits == 512 + 64*i:
                return self._generate(bits, randfunc, progress_func)

        # The March 2006 draft of FIPS 186-3 also allows 2048 and 3072-bit
        # primes, but only with longer q values.  Since the current DSA
        # implementation only supports a 160-bit q, we don't support larger
        # values.
        raise ValueError("Number of bits in p must be a multiple of 64 between 512 and 1024, not %d bits" % (bits,))

    def _generate(self, bits, randfunc=None, progress_func=None):
        rf = self._get_randfunc(randfunc)
        obj = _DSA.generate_py(bits, rf, progress_func)    # TODO: Don't use legacy _DSA module
        key = self._math.dsa_construct(obj.y, obj.g, obj.p, obj.q, obj.x)
        return _DSAobj(self, key)

    def construct(self, tup):
        """Construct a DSA key from a tuple of valid DSA components.

        The modulus *p* must be a prime.

        The following equations must apply:

        - p-1 = 0 mod q
        - g^x = y mod p
        - 0 < x < q
        - 1 < g < p

        :Parameters:
         tup : tuple
                    A tuple of long integers, with 4 or 5 items
                    in the following order:

                    1. Public key (*y*).
                    2. Sub-group generator (*g*).
                    3. Modulus, finite field order (*p*).
                    4. Sub-group order (*q*).
                    5. Private key (*x*). Optional.

        :Return: A DSA key object (`_DSAobj`).
        """
        key = self._math.dsa_construct(*tup)
        return _DSAobj(self, key)

_impl = DSAImplementation()
generate = _impl.generate
construct = _impl.construct
error = _impl.error

# vim:set ts=4 sw=4 sts=4 expandtab:

