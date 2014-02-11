# -*- coding: utf-8 -*-
#
#  SelfTest/Cipher/XOR.py: Self-test for the XOR "cipher"
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

"""Self-test suite for Crypto.Cipher.XOR"""

import unittest

__revision__ = "$Id$"

from Crypto.Util.py3compat import *

# This is a list of (plaintext, ciphertext, key) tuples.
test_data = [
    # Test vectors written from scratch.  (Nobody posts XOR test vectors on the web?  How disappointing.)
    ('01', '01',
        '00',
        'zero key'),

    ('0102040810204080', '0003050911214181',
        '01',
        '1-byte key'),

    ('0102040810204080', 'cda8c8a2dc8a8c2a',
        'ccaa',
        '2-byte key'),

    ('ff'*64, 'fffefdfcfbfaf9f8f7f6f5f4f3f2f1f0efeeedecebeae9e8e7e6e5e4e3e2e1e0'*2,
        '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
        '32-byte key'),
]

class TruncationSelfTest(unittest.TestCase):

    def runTest(self):
        """33-byte key (should raise ValueError under current implementation)"""
        # Crypto.Cipher.XOR previously truncated its inputs at 32 bytes.  Now
        # it should raise a ValueError if the length is too long.
        self.assertRaises(ValueError, XOR.new, "x"*33)

def get_tests(config={}):
    global XOR
    from Crypto.Cipher import XOR
    from common import make_stream_tests
    return make_stream_tests(XOR, "XOR", test_data) + [TruncationSelfTest()]

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
