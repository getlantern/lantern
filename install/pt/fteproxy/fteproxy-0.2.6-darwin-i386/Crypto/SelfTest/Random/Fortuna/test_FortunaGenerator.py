# -*- coding: utf-8 -*-
#
#  SelfTest/Random/Fortuna/test_FortunaGenerator.py: Self-test for the FortunaGenerator module
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

"""Self-tests for Crypto.Random.Fortuna.FortunaGenerator"""

__revision__ = "$Id$"

import sys
if sys.version_info[0] == 2 and sys.version_info[1] == 1:
    from Crypto.Util.py21compat import *
from Crypto.Util.py3compat import *

import unittest
from binascii import b2a_hex

class FortunaGeneratorTests(unittest.TestCase):
    def setUp(self):
        global FortunaGenerator
        from Crypto.Random.Fortuna import FortunaGenerator

    def test_generator(self):
        """FortunaGenerator.AESGenerator"""
        fg = FortunaGenerator.AESGenerator()

        # We shouldn't be able to read data until we've seeded the generator
        self.assertRaises(Exception, fg.pseudo_random_data, 1)
        self.assertEqual(0, fg.counter.next_value())

        # Seed the generator, which should set the key and increment the counter.
        fg.reseed(b("Hello"))
        self.assertEqual(b("0ea6919d4361551364242a4ba890f8f073676e82cf1a52bb880f7e496648b565"), b2a_hex(fg.key))
        self.assertEqual(1, fg.counter.next_value())

        # Read 2 full blocks from the generator
        self.assertEqual(b("7cbe2c17684ac223d08969ee8b565616") +       # counter=1
                         b("717661c0d2f4758bd6ba140bf3791abd"),        # counter=2
            b2a_hex(fg.pseudo_random_data(32)))

        # Meanwhile, the generator will have re-keyed itself and incremented its counter
        self.assertEqual(b("33a1bb21987859caf2bbfc5615bef56d") +       # counter=3
                         b("e6b71ff9f37112d0c193a135160862b7"),        # counter=4
            b2a_hex(fg.key))
        self.assertEqual(5, fg.counter.next_value())

        # Read another 2 blocks from the generator
        self.assertEqual(b("fd6648ba3086e919cee34904ef09a7ff") +       # counter=5
                         b("021f77580558b8c3e9248275f23042bf"),        # counter=6
            b2a_hex(fg.pseudo_random_data(32)))


        # Try to read more than 2**20 bytes using the internal function.  This should fail.
        self.assertRaises(AssertionError, fg._pseudo_random_data, 2**20+1)

def get_tests(config={}):
    from Crypto.SelfTest.st_common import list_test_cases
    return list_test_cases(FortunaGeneratorTests)

if __name__ == '__main__':
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
