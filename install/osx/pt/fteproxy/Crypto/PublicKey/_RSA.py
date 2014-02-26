#
#   RSA.py : RSA encryption/decryption
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

from Crypto.PublicKey import pubkey
from Crypto.Util import number

def generate_py(bits, randfunc, progress_func=None, e=65537):
    """generate(bits:int, randfunc:callable, progress_func:callable, e:int)

    Generate an RSA key of length 'bits', public exponent 'e'(which must be
    odd), using 'randfunc' to get random data and 'progress_func',
    if present, to display the progress of the key generation.
    """
    obj=RSAobj()
    obj.e = long(e)

    # Generate the prime factors of n
    if progress_func:
        progress_func('p,q\n')
    p = q = 1L
    while number.size(p*q) < bits:
        # Note that q might be one bit longer than p if somebody specifies an odd
        # number of bits for the key. (Why would anyone do that?  You don't get
        # more security.)
        p = pubkey.getStrongPrime(bits>>1, obj.e, 1e-12, randfunc)
        q = pubkey.getStrongPrime(bits - (bits>>1), obj.e, 1e-12, randfunc)

    # It's OK for p to be larger than q, but let's be
    # kind to the function that will invert it for
    # th calculation of u.
    if p > q:
        (p, q)=(q, p)
    obj.p = p
    obj.q = q

    if progress_func:
        progress_func('u\n')
    obj.u = pubkey.inverse(obj.p, obj.q)
    obj.n = obj.p*obj.q

    if progress_func:
        progress_func('d\n')
    obj.d=pubkey.inverse(obj.e, (obj.p-1)*(obj.q-1))

    assert bits <= 1+obj.size(), "Generated key is too small"

    return obj

class RSAobj(pubkey.pubkey):

    def size(self):
        """size() : int
        Return the maximum number of bits that can be handled by this key.
        """
        return number.size(self.n) - 1

