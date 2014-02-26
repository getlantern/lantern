# HMAC.py - Implements the HMAC algorithm as described by RFC 2104.
#
# ===================================================================
# Portions Copyright (c) 2001, 2002, 2003 Python Software Foundation;
# All Rights Reserved
#
# This file contains code from the Python 2.2 hmac.py module (the
# "Original Code"), with modifications made after it was incorporated
# into PyCrypto (the "Modifications").
#
# To the best of our knowledge, the Python Software Foundation is the
# copyright holder of the Original Code, and has licensed it under the
# Python 2.2 license.  See the file LEGAL/copy/LICENSE.python-2.2 for
# details.
#
# The Modifications to this file are dedicated to the public domain.
# To the extent that dedication to the public domain is not available,
# everyone is granted a worldwide, perpetual, royalty-free,
# non-exclusive license to exercise all rights associated with the
# contents of this file for any purpose whatsoever.  No rights are
# reserved.
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


"""HMAC (Hash-based Message Authentication Code) algorithm

HMAC is a MAC defined in RFC2104_ and FIPS-198_ and constructed using
a cryptograpic hash algorithm.
It is usually named *HMAC-X*, where *X* is the hash algorithm; for
instance *HMAC-SHA1* or *HMAC-MD5*.

The strength of an HMAC depends on:

 - the strength of the hash algorithm
 - the length and entropy of the secret key

An example of possible usage is the following:

    >>> from Crypto.Hash import HMAC
    >>>
    >>> secret = b'Swordfish'
    >>> h = HMAC.new(secret)
    >>> h.update(b'Hello')
    >>> print h.hexdigest()

.. _RFC2104: http://www.ietf.org/rfc/rfc2104.txt
.. _FIPS-198: http://csrc.nist.gov/publications/fips/fips198/fips-198a.pdf
"""

# This is just a copy of the Python 2.2 HMAC module, modified to work when
# used on versions of Python before 2.2.

__revision__ = "$Id$"

__all__ = ['new', 'digest_size', 'HMAC' ]

from Crypto.Util.strxor import strxor_c
from Crypto.Util.py3compat import *

#: The size of the authentication tag produced by the MAC.
#: It matches the digest size on the underlying
#: hashing module used.
digest_size = None

class HMAC:
    """Class that implements HMAC"""

    #: The size of the authentication tag produced by the MAC.
    #: It matches the digest size on the underlying
    #: hashing module used.
    digest_size = None
    
    def __init__(self, key, msg = None, digestmod = None):
        """Create a new HMAC object.

        :Parameters:
          key : byte string
            secret key for the MAC object.
            It must be long enough to match the expected security level of the
            MAC. However, there is no benefit in using keys longer than the
            `digest_size` of the underlying hash algorithm.
          msg : byte string
            The very first chunk of the message to authenticate.
            It is equivalent to an early call to `update()`. Optional.
        :Parameter digestmod:
            The hash algorithm the HMAC is based on.
            Default is `Crypto.Hash.MD5`.
        :Type digestmod:
            A hash module or object instantiated from `Crypto.Hash`
        """
        if digestmod is None:
            import MD5
            digestmod = MD5

        self.digestmod = digestmod
        self.outer = digestmod.new()
        self.inner = digestmod.new()
        try:
            self.digest_size = digestmod.digest_size
        except AttributeError:
            self.digest_size = len(self.outer.digest())

        try:
            # The block size is 128 bytes for SHA384 and SHA512 and 64 bytes
            # for the others hash function
            blocksize = digestmod.block_size
        except AttributeError:
            blocksize = 64

        ipad = 0x36
        opad = 0x5C

        if len(key) > blocksize:
            key = digestmod.new(key).digest()

        key = key + bchr(0) * (blocksize - len(key))
        self.outer.update(strxor_c(key, opad))
        self.inner.update(strxor_c(key, ipad))
        if (msg):
            self.update(msg)

    def update(self, msg):
        """Continue authentication of a message by consuming the next chunk of data.
        
        Repeated calls are equivalent to a single call with the concatenation
        of all the arguments. In other words:

           >>> m.update(a); m.update(b)
           
        is equivalent to:
        
           >>> m.update(a+b)

        :Parameters:
          msg : byte string
            The next chunk of the message being authenticated
        """
 
        self.inner.update(msg)

    def copy(self):
        """Return a copy ("clone") of the MAC object.

        The copy will have the same internal state as the original MAC
        object.
        This can be used to efficiently compute the MAC of strings that
        share a common initial substring.

        :Returns: An `HMAC` object
        """
        other = HMAC(b(""))
        other.digestmod = self.digestmod
        other.inner = self.inner.copy()
        other.outer = self.outer.copy()
        return other

    def digest(self):
        """Return the **binary** (non-printable) MAC of the message that has
        been authenticated so far.

        This method does not change the state of the MAC object.
        You can continue updating the object after calling this function.
        
        :Return: A byte string of `digest_size` bytes. It may contain non-ASCII
         characters, including null bytes.
        """
        h = self.outer.copy()
        h.update(self.inner.digest())
        return h.digest()

    def hexdigest(self):
        """Return the **printable** MAC of the message that has been
        authenticated so far.

        This method does not change the state of the MAC object.
        
        :Return: A string of 2* `digest_size` bytes. It contains only
         hexadecimal ASCII digits.
        """
        return "".join(["%02x" % bord(x)
                  for x in tuple(self.digest())])

def new(key, msg = None, digestmod = None):
    """Create a new HMAC object.

    :Parameters:
      key : byte string
        key for the MAC object.
        It must be long enough to match the expected security level of the
        MAC. However, there is no benefit in using keys longer than the
        `digest_size` of the underlying hash algorithm.
      msg : byte string
        The very first chunk of the message to authenticate.
        It is equivalent to an early call to `HMAC.update()`.
        Optional.
    :Parameter digestmod:
        The hash to use to implement the HMAC. Default is `Crypto.Hash.MD5`.
    :Type digestmod:
        A hash module or instantiated object from `Crypto.Hash`
    :Returns: An `HMAC` object
    """
    return HMAC(key, msg, digestmod)

