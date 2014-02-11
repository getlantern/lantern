# -*- coding: utf-8 -*-
#
#  SelfTest/Util/test_Counter: Self-test for the Crypto.Util.Counter module
#
# Written in 2009 by Dwayne C. Litzenberger <dlitz@dlitz.net>
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

"""Self-tests for Crypto.Util.Counter"""

__revision__ = "$Id$"

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *
from Crypto.Util.py3compat import *

import unittest

class CounterTests(unittest.TestCase):
    def setUp(self):
        global Counter
        from Crypto.Util import Counter

    def test_BE_shortcut(self):
        """Big endian, shortcut enabled"""
        c = Counter.new(128)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_
        c = Counter.new(128, little_endian=False)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_
        c = Counter.new(128, disable_shortcut=False)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_
        c = Counter.new(128, little_endian=False, disable_shortcut=False)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_

    def test_LE_shortcut(self):
        """Little endian, shortcut enabled"""
        c = Counter.new(128, little_endian=True)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_
        c = Counter.new(128, little_endian=True, disable_shortcut=False)
        self.assertEqual(c.__PCT_CTR_SHORTCUT__,True) # assert_

    def test_BE_no_shortcut(self):
        """Big endian, shortcut disabled"""
        c = Counter.new(128, disable_shortcut=True)
        self.assertRaises(AttributeError, getattr, c, '__PCT_CTR_SHORTCUT__')
        c = Counter.new(128, little_endian=False, disable_shortcut=True)
        self.assertRaises(AttributeError, getattr, c, '__PCT_CTR_SHORTCUT__')

    def test_LE_no_shortcut(self):
        """Little endian, shortcut disabled"""
        c = Counter.new(128, little_endian=True, disable_shortcut=True)
        self.assertRaises(AttributeError, getattr, c, '__PCT_CTR_SHORTCUT__')

    def test_BE_defaults(self):
        """128-bit, Big endian, defaults"""
        c = Counter.new(128)
        self.assertEqual(1, c.next_value())
        self.assertEqual(b("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01"), c())
        self.assertEqual(2, c.next_value())
        self.assertEqual(b("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02"), c())
        for i in xrange(3, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(b("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")+bchr(i), c())
        self.assertEqual(256, c.next_value())
        self.assertEqual(b("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00"), c())

    def test_LE_defaults(self):
        """128-bit, Little endian, defaults"""
        c = Counter.new(128, little_endian=True)
        self.assertEqual(1, c.next_value())
        self.assertEqual(b("\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"), c())
        self.assertEqual(2, c.next_value())
        self.assertEqual(b("\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"), c())
        for i in xrange(3, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i)+b("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"), c())
        self.assertEqual(256, c.next_value())
        self.assertEqual(b("\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"), c())

    def test_BE8_wraparound(self):
        """8-bit, Big endian, wraparound"""
        c = Counter.new(8)
        for i in xrange(1, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertRaises(OverflowError, c.next_value)
        self.assertRaises(OverflowError, c)
        self.assertRaises(OverflowError, c.next_value)
        self.assertRaises(OverflowError, c)

    def test_LE8_wraparound(self):
        """8-bit, Little endian, wraparound"""
        c = Counter.new(8, little_endian=True)
        for i in xrange(1, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertRaises(OverflowError, c.next_value)
        self.assertRaises(OverflowError, c)
        self.assertRaises(OverflowError, c.next_value)
        self.assertRaises(OverflowError, c)

    def test_BE8_wraparound_allowed(self):
        """8-bit, Big endian, wraparound with allow_wraparound=True"""
        c = Counter.new(8, allow_wraparound=True)
        for i in xrange(1, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertEqual(0, c.next_value())
        self.assertEqual(b("\x00"), c())
        self.assertEqual(1, c.next_value())

    def test_LE8_wraparound_allowed(self):
        """8-bit, Little endian, wraparound with allow_wraparound=True"""
        c = Counter.new(8, little_endian=True, allow_wraparound=True)
        for i in xrange(1, 256):
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertEqual(0, c.next_value())
        self.assertEqual(b("\x00"), c())
        self.assertEqual(1, c.next_value())

    def test_BE8_carry(self):
        """8-bit, Big endian, carry attribute"""
        c = Counter.new(8)
        for i in xrange(1, 256):
            self.assertEqual(0, c.carry)
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertEqual(1, c.carry)

    def test_LE8_carry(self):
        """8-bit, Little endian, carry attribute"""
        c = Counter.new(8, little_endian=True)
        for i in xrange(1, 256):
            self.assertEqual(0, c.carry)
            self.assertEqual(i, c.next_value())
            self.assertEqual(bchr(i), c())
        self.assertEqual(1, c.carry)

def get_tests(config={}):
    from Crypto.SelfTest.st_common import list_test_cases
    return list_test_cases(CounterTests)

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
