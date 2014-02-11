# -*- coding: utf-8 -*-
#
#  SelfTest/Cipher/CAST.py: Self-test for the CAST-128 (CAST5) cipher
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

"""Self-test suite for Crypto.Cipher.CAST"""

__revision__ = "$Id$"

from Crypto.Util.py3compat import *

# This is a list of (plaintext, ciphertext, key) tuples.
test_data = [
    # Test vectors from RFC 2144, B.1
    ('0123456789abcdef', '238b4fe5847e44b2',
        '0123456712345678234567893456789a',
        '128-bit key'),

    ('0123456789abcdef', 'eb6a711a2c02271b',
        '01234567123456782345',
        '80-bit key'),

    ('0123456789abcdef', '7ac816d16e9b302e',
        '0123456712',
        '40-bit key'),
]

def get_tests(config={}):
    from Crypto.Cipher import CAST
    from common import make_block_tests
    return make_block_tests(CAST, "CAST", test_data)

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
