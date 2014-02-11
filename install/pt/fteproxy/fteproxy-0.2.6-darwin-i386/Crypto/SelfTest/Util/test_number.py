# -*- coding: utf-8 -*-
#
#  SelfTest/Util/test_number.py: Self-test for parts of the Crypto.Util.number module
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

"""Self-tests for (some of) Crypto.Util.number"""

__revision__ = "$Id$"

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *

import unittest

# NB: In some places, we compare tuples instead of just output values so that
# if any inputs cause a test failure, we'll be able to tell which ones.

class MiscTests(unittest.TestCase):
    def setUp(self):
        global number, math
        from Crypto.Util import number
        import math

    def test_ceil_shift(self):
        """Util.number.ceil_shift"""
        self.assertRaises(AssertionError, number.ceil_shift, -1, 1)
        self.assertRaises(AssertionError, number.ceil_shift, 1, -1)

        # b = 0
        self.assertEqual(0, number.ceil_shift(0, 0))
        self.assertEqual(1, number.ceil_shift(1, 0))
        self.assertEqual(2, number.ceil_shift(2, 0))
        self.assertEqual(3, number.ceil_shift(3, 0))

        # b = 1
        self.assertEqual(0, number.ceil_shift(0, 1))
        self.assertEqual(1, number.ceil_shift(1, 1))
        self.assertEqual(1, number.ceil_shift(2, 1))
        self.assertEqual(2, number.ceil_shift(3, 1))

        # b = 2
        self.assertEqual(0, number.ceil_shift(0, 2))
        self.assertEqual(1, number.ceil_shift(1, 2))
        self.assertEqual(1, number.ceil_shift(2, 2))
        self.assertEqual(1, number.ceil_shift(3, 2))
        self.assertEqual(1, number.ceil_shift(4, 2))
        self.assertEqual(2, number.ceil_shift(5, 2))
        self.assertEqual(2, number.ceil_shift(6, 2))
        self.assertEqual(2, number.ceil_shift(7, 2))
        self.assertEqual(2, number.ceil_shift(8, 2))
        self.assertEqual(3, number.ceil_shift(9, 2))

        for b in range(3, 1+129, 3):    # 3, 6, ... , 129
            self.assertEqual(0, number.ceil_shift(0, b))

            n = 1L
            while n <= 2L**(b+2):
                (q, r) = divmod(n-1, 2L**b)
                expected = q + int(not not r)
                self.assertEqual((n-1, b, expected),
                                 (n-1, b, number.ceil_shift(n-1, b)))

                (q, r) = divmod(n, 2L**b)
                expected = q + int(not not r)
                self.assertEqual((n, b, expected),
                                 (n, b, number.ceil_shift(n, b)))

                (q, r) = divmod(n+1, 2L**b)
                expected = q + int(not not r)
                self.assertEqual((n+1, b, expected),
                                 (n+1, b, number.ceil_shift(n+1, b)))

                n *= 2

    def test_ceil_div(self):
        """Util.number.ceil_div"""
        self.assertRaises(TypeError, number.ceil_div, "1", 1)
        self.assertRaises(ZeroDivisionError, number.ceil_div, 1, 0)
        self.assertRaises(ZeroDivisionError, number.ceil_div, -1, 0)

        # b = -1
        self.assertEqual(0, number.ceil_div(0, -1))
        self.assertEqual(-1, number.ceil_div(1, -1))
        self.assertEqual(-2, number.ceil_div(2, -1))
        self.assertEqual(-3, number.ceil_div(3, -1))

        # b = 1
        self.assertEqual(0, number.ceil_div(0, 1))
        self.assertEqual(1, number.ceil_div(1, 1))
        self.assertEqual(2, number.ceil_div(2, 1))
        self.assertEqual(3, number.ceil_div(3, 1))

        # b = 2
        self.assertEqual(0, number.ceil_div(0, 2))
        self.assertEqual(1, number.ceil_div(1, 2))
        self.assertEqual(1, number.ceil_div(2, 2))
        self.assertEqual(2, number.ceil_div(3, 2))
        self.assertEqual(2, number.ceil_div(4, 2))
        self.assertEqual(3, number.ceil_div(5, 2))

        # b = 3
        self.assertEqual(0, number.ceil_div(0, 3))
        self.assertEqual(1, number.ceil_div(1, 3))
        self.assertEqual(1, number.ceil_div(2, 3))
        self.assertEqual(1, number.ceil_div(3, 3))
        self.assertEqual(2, number.ceil_div(4, 3))
        self.assertEqual(2, number.ceil_div(5, 3))
        self.assertEqual(2, number.ceil_div(6, 3))
        self.assertEqual(3, number.ceil_div(7, 3))

        # b = 4
        self.assertEqual(0, number.ceil_div(0, 4))
        self.assertEqual(1, number.ceil_div(1, 4))
        self.assertEqual(1, number.ceil_div(2, 4))
        self.assertEqual(1, number.ceil_div(3, 4))
        self.assertEqual(1, number.ceil_div(4, 4))
        self.assertEqual(2, number.ceil_div(5, 4))
        self.assertEqual(2, number.ceil_div(6, 4))
        self.assertEqual(2, number.ceil_div(7, 4))
        self.assertEqual(2, number.ceil_div(8, 4))
        self.assertEqual(3, number.ceil_div(9, 4))

        # b = -4
        self.assertEqual(3, number.ceil_div(-9, -4))
        self.assertEqual(2, number.ceil_div(-8, -4))
        self.assertEqual(2, number.ceil_div(-7, -4))
        self.assertEqual(2, number.ceil_div(-6, -4))
        self.assertEqual(2, number.ceil_div(-5, -4))
        self.assertEqual(1, number.ceil_div(-4, -4))
        self.assertEqual(1, number.ceil_div(-3, -4))
        self.assertEqual(1, number.ceil_div(-2, -4))
        self.assertEqual(1, number.ceil_div(-1, -4))
        self.assertEqual(0, number.ceil_div(0, -4))
        self.assertEqual(0, number.ceil_div(1, -4))
        self.assertEqual(0, number.ceil_div(2, -4))
        self.assertEqual(0, number.ceil_div(3, -4))
        self.assertEqual(-1, number.ceil_div(4, -4))
        self.assertEqual(-1, number.ceil_div(5, -4))
        self.assertEqual(-1, number.ceil_div(6, -4))
        self.assertEqual(-1, number.ceil_div(7, -4))
        self.assertEqual(-2, number.ceil_div(8, -4))
        self.assertEqual(-2, number.ceil_div(9, -4))

    def test_exact_log2(self):
        """Util.number.exact_log2"""
        self.assertRaises(TypeError, number.exact_log2, "0")
        self.assertRaises(ValueError, number.exact_log2, -1)
        self.assertRaises(ValueError, number.exact_log2, 0)
        self.assertEqual(0, number.exact_log2(1))
        self.assertEqual(1, number.exact_log2(2))
        self.assertRaises(ValueError, number.exact_log2, 3)
        self.assertEqual(2, number.exact_log2(4))
        self.assertRaises(ValueError, number.exact_log2, 5)
        self.assertRaises(ValueError, number.exact_log2, 6)
        self.assertRaises(ValueError, number.exact_log2, 7)
        e = 3
        n = 8
        while e < 16:
            if n == 2**e:
                self.assertEqual(e, number.exact_log2(n), "expected=2**%d, n=%d" % (e, n))
                e += 1
            else:
                self.assertRaises(ValueError, number.exact_log2, n)
            n += 1

        for e in range(16, 1+64, 2):
            self.assertRaises(ValueError, number.exact_log2, 2L**e-1)
            self.assertEqual(e, number.exact_log2(2L**e))
            self.assertRaises(ValueError, number.exact_log2, 2L**e+1)

    def test_exact_div(self):
        """Util.number.exact_div"""

        # Positive numbers
        self.assertEqual(1, number.exact_div(1, 1))
        self.assertRaises(ValueError, number.exact_div, 1, 2)
        self.assertEqual(1, number.exact_div(2, 2))
        self.assertRaises(ValueError, number.exact_div, 3, 2)
        self.assertEqual(2, number.exact_div(4, 2))

        # Negative numbers
        self.assertEqual(-1, number.exact_div(-1, 1))
        self.assertEqual(-1, number.exact_div(1, -1))
        self.assertRaises(ValueError, number.exact_div, -1, 2)
        self.assertEqual(1, number.exact_div(-2, -2))
        self.assertEqual(-2, number.exact_div(-4, 2))

        # Zero dividend
        self.assertEqual(0, number.exact_div(0, 1))
        self.assertEqual(0, number.exact_div(0, 2))

        # Zero divisor (allow_divzero == False)
        self.assertRaises(ZeroDivisionError, number.exact_div, 0, 0)
        self.assertRaises(ZeroDivisionError, number.exact_div, 1, 0)

        # Zero divisor (allow_divzero == True)
        self.assertEqual(0, number.exact_div(0, 0, allow_divzero=True))
        self.assertRaises(ValueError, number.exact_div, 1, 0, allow_divzero=True)

    def test_floor_div(self):
        """Util.number.floor_div"""
        self.assertRaises(TypeError, number.floor_div, "1", 1)
        for a in range(-10, 10):
            for b in range(-10, 10):
                if b == 0:
                    self.assertRaises(ZeroDivisionError, number.floor_div, a, b)
                else:
                    self.assertEqual((a, b, int(math.floor(float(a) / b))),
                                     (a, b, number.floor_div(a, b)))

    def test_getStrongPrime(self):
        """Util.number.getStrongPrime"""
        self.assertRaises(ValueError, number.getStrongPrime, 256)
        self.assertRaises(ValueError, number.getStrongPrime, 513)
        bits = 512
        x = number.getStrongPrime(bits)
        self.assertNotEqual(x % 2, 0)
        self.assertEqual(x > (1L << bits-1)-1, 1)
        self.assertEqual(x < (1L << bits), 1)
        e = 2**16+1
        x = number.getStrongPrime(bits, e)
        self.assertEqual(number.GCD(x-1, e), 1)
        self.assertNotEqual(x % 2, 0)
        self.assertEqual(x > (1L << bits-1)-1, 1)
        self.assertEqual(x < (1L << bits), 1)
        e = 2**16+2
        x = number.getStrongPrime(bits, e)
        self.assertEqual(number.GCD((x-1)>>1, e), 1)
        self.assertNotEqual(x % 2, 0)
        self.assertEqual(x > (1L << bits-1)-1, 1)
        self.assertEqual(x < (1L << bits), 1)

    def test_isPrime(self):
        """Util.number.isPrime"""
        self.assertEqual(number.isPrime(-3), False)     # Regression test: negative numbers should not be prime
        self.assertEqual(number.isPrime(-2), False)     # Regression test: negative numbers should not be prime
        self.assertEqual(number.isPrime(1), False)      # Regression test: isPrime(1) caused some versions of PyCrypto to crash.
        self.assertEqual(number.isPrime(2), True)
        self.assertEqual(number.isPrime(3), True)
        self.assertEqual(number.isPrime(4), False)
        self.assertEqual(number.isPrime(2L**1279-1), True)
        self.assertEqual(number.isPrime(-(2L**1279-1)), False)     # Regression test: negative numbers should not be prime
        # test some known gmp pseudo-primes taken from
        # http://www.trnicely.net/misc/mpzspsp.html
        for composite in (43 * 127 * 211, 61 * 151 * 211, 15259 * 30517,
                          346141L * 692281L, 1007119L * 2014237L, 3589477L * 7178953L,
                          4859419L * 9718837L, 2730439L * 5460877L,
                          245127919L * 490255837L, 963939391L * 1927878781L,
                          4186358431L * 8372716861L, 1576820467L * 3153640933L):
            self.assertEqual(number.isPrime(long(composite)), False)

    def test_size(self):
        self.assertEqual(number.size(2),2)
        self.assertEqual(number.size(3),2)
        self.assertEqual(number.size(0xa2),8)
        self.assertEqual(number.size(0xa2ba40),8*3)
        self.assertEqual(number.size(0xa2ba40ee07e3b2bd2f02ce227f36a195024486e49c19cb41bbbdfbba98b22b0e577c2eeaffa20d883a76e65e394c69d4b3c05a1e8fadda27edb2a42bc000fe888b9b32c22d15add0cd76b3e7936e19955b220dd17d4ea904b1ec102b2e4de7751222aa99151024c7cb41cc5ea21d00eeb41f7c800834d2c6e06bce3bce7ea9a5L), 1024)

    def test_negative_number_roundtrip_mpzToLongObj_longObjToMPZ(self):
        """Test that mpzToLongObj and longObjToMPZ (internal functions) roundtrip negative numbers correctly."""
        n = -100000000000000000000000000000000000L
        e = 2L
        k = number._fastmath.rsa_construct(n, e)
        self.assertEqual(n, k.n)
        self.assertEqual(e, k.e)

def get_tests(config={}):
    from Crypto.SelfTest.st_common import list_test_cases
    return list_test_cases(MiscTests)

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
