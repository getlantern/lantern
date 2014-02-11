# -*- coding: utf-8 -*-
#
#  SelfTest/Hash/SHA.py: Self-test for the SHA-1 hash function
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

"""Self-test suite for Crypto.Hash.SHA"""

__revision__ = "$Id$"

from Crypto.Util.py3compat import *

# Test vectors from various sources
# This is a list of (expected_result, input[, description]) tuples.
test_data = [
    # FIPS PUB 180-2, A.1 - "One-Block Message"
    ('a9993e364706816aba3e25717850c26c9cd0d89d', 'abc'),

    # FIPS PUB 180-2, A.2 - "Multi-Block Message"
    ('84983e441c3bd26ebaae4aa1f95129e5e54670f1',
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),

    # FIPS PUB 180-2, A.3 - "Long Message"
#    ('34aa973cd4c4daa4f61eeb2bdbad27316534016f',
#        'a' * 10**6,
#         '"a" * 10**6'),

    # RFC 3174: Section 7.3, "TEST4" (multiple of 512 bits)
    ('dea356a2cddd90c7a7ecedc5ebb563934f460452',
        '01234567' * 80,
        '"01234567" * 80'),
]

def get_tests(config={}):
    from Crypto.Hash import SHA
    from common import make_hash_tests
    return make_hash_tests(SHA, "SHA", test_data,
        digest_size=20,
        oid="\x06\x05\x2B\x0E\x03\x02\x1A")

if __name__ == '__main__':
    import unittest
    suite = lambda: unittest.TestSuite(get_tests())
    unittest.main(defaultTest='suite')

# vim:set ts=4 sw=4 sts=4 expandtab:
